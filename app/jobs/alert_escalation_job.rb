class AlertEscalationJob < ApplicationJob
  queue_as :alerts
  retry_on StandardError, wait: :exponentially_longer, attempts: 2

  def perform(alert_id)
    alert = Alert.find(alert_id)
    return unless alert.active? # Only escalate active alerts

    escalate_alert(alert)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "Alert #{alert_id} not found for escalation"
  end

  private

  def escalate_alert(alert)
    # Mark original alert as escalated
    alert.escalate!

    escalation_level = alert.escalation_level || 1
    
    case escalation_level
    when 1
      escalate_to_operations_admin(alert)
    when 2
      escalate_to_management(alert)
    when 3
      escalate_to_super_admin(alert)
    else
      Rails.logger.warn "Maximum escalation level reached for alert #{alert.id}"
    end

    # Schedule next escalation if still unacknowledged
    if escalation_level < 3
      AlertEscalationJob.set(wait: escalation_wait_time(escalation_level))
                       .perform_later(alert.id)
    end
  end

  def escalate_to_operations_admin(alert)
    operations_admins = User.where(role: :operations_admin)
    
    operations_admins.find_each do |admin|
      escalation_alert = alert.flight_request.alerts.create!(
        alert_type: :escalation,
        user: admin,
        title: "ESCALATED: #{alert.title}",
        message: build_escalation_message(alert, "Operations Admin", 1),
        priority: escalate_priority(alert.priority),
        status: :active,
        metadata: alert.metadata.merge({
          original_alert_id: alert.id,
          escalation_level: 1,
          escalated_from: alert.user.role
        })
      )

      NotificationDeliveryJob.perform_later(escalation_alert.id)
    end

    Rails.logger.info "Alert #{alert.id} escalated to Operations Admin level"
  end

  def escalate_to_management(alert)
    management_users = User.where(role: :management)
    
    management_users.find_each do |manager|
      escalation_alert = alert.flight_request.alerts.create!(
        alert_type: :escalation,
        user: manager,
        title: "MANAGEMENT ESCALATION: #{alert.title}",
        message: build_escalation_message(alert, "Management", 2),
        priority: :critical,
        status: :active,
        metadata: alert.metadata.merge({
          original_alert_id: alert.id,
          escalation_level: 2,
          escalated_from: alert.user.role
        })
      )

      NotificationDeliveryJob.perform_later(escalation_alert.id)
    end

    Rails.logger.info "Alert #{alert.id} escalated to Management level"
  end

  def escalate_to_super_admin(alert)
    super_admins = User.where(role: :super_admin)
    
    super_admins.find_each do |admin|
      escalation_alert = alert.flight_request.alerts.create!(
        alert_type: :escalation,
        user: admin,
        title: "CRITICAL SYSTEM ESCALATION: #{alert.title}",
        message: build_escalation_message(alert, "Super Admin", 3),
        priority: :critical,
        status: :active,
        metadata: alert.metadata.merge({
          original_alert_id: alert.id,
          escalation_level: 3,
          escalated_from: alert.user.role
        })
      )

      NotificationDeliveryJob.perform_later(escalation_alert.id)
    end

    Rails.logger.error "Alert #{alert.id} escalated to Super Admin - CRITICAL"
  end

  def build_escalation_message(original_alert, level, escalation_number)
    <<~MESSAGE
      🚨 ESCALATION LEVEL #{escalation_number}: #{level} Attention Required

      Original Alert: #{original_alert.title}
      Flight Request: #{original_alert.flight_request.request_number}
      Original Priority: #{original_alert.priority.humanize}
      Created: #{original_alert.created_at.strftime('%B %d, %Y at %H:%M')}
      
      This alert has been unacknowledged for an extended period and requires immediate attention.
      
      Original Message:
      #{original_alert.message}
      
      Please review and take appropriate action immediately.
    MESSAGE
  end

  def escalate_priority(current_priority)
    case current_priority
    when "low" then :medium
    when "medium" then :high
    when "high" then :urgent
    when "urgent", "critical" then :critical
    else :critical
    end
  end

  def escalation_wait_time(level)
    case level
    when 1 then 2.hours  # Wait 2 hours before escalating to management
    when 2 then 1.hour   # Wait 1 hour before escalating to super admin
    else 30.minutes      # Final escalation
    end
  end
end
