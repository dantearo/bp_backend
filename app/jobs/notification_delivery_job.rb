class NotificationDeliveryJob < ApplicationJob
  queue_as :notifications
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(alert_id)
    alert = Alert.find(alert_id)
    return unless alert.active?

    # Create and deliver email notification
    create_and_deliver_email_notification(alert)
    
    # Create in-app notification
    create_in_app_notification(alert)
    
    # Future: SMS and push notifications
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "Alert #{alert_id} not found for notification delivery"
  end

  private

  def create_and_deliver_email_notification(alert)
    return unless alert.user.email.present?

    notification = alert.notifications.create!(
      notification_type: :alert_notification,
      recipient: alert.user,
      subject: alert.title,
      content: alert.message,
      delivery_method: :email,
      status: :pending
    )

    begin
      # Use Rails ActionMailer
      AlertMailer.flight_alert(notification.id).deliver_now
      notification.mark_sent!
      Rails.logger.info "Email notification sent for alert #{alert.id} to #{alert.user.email}"
    rescue => e
      notification.mark_failed!(e.message)
      Rails.logger.error "Failed to send email notification for alert #{alert.id}: #{e.message}"
      raise e
    end
  end

  def create_in_app_notification(alert)
    notification = alert.notifications.create!(
      notification_type: :alert_notification,
      recipient: alert.user,
      subject: alert.title,
      content: alert.message,
      delivery_method: :in_app,
      status: :sent,
      sent_at: Time.current
    )

    Rails.logger.info "In-app notification created for alert #{alert.id}"
  end
end
