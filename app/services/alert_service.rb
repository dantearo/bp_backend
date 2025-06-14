class AlertService
  def self.create_flight_request_alert(flight_request, alert_type, recipients, options = {})
    return if recipients.empty?

    priority = options[:priority] || :medium
    title = options[:title] || "Flight Request Alert"
    message = options[:message] || "Alert for flight request #{flight_request.request_number}"

    alerts_created = []

    recipients.each do |user|
      alert = flight_request.alerts.create!(
        alert_type: alert_type,
        user: user,
        title: title,
        message: message,
        priority: priority,
        status: :active,
        metadata: options[:metadata] || {}
      )

      alerts_created << alert
      
      # Queue notification delivery
      NotificationDeliveryJob.perform_later(alert.id)
    end

    alerts_created
  end

  def self.create_status_change_alert(flight_request, old_status, new_status)
    return unless should_notify_status_change?(old_status, new_status)

    recipients = get_status_change_recipients(flight_request, new_status)
    priority = determine_status_change_priority(new_status)

    create_flight_request_alert(
      flight_request,
      :status_change,
      recipients,
      {
        title: "Flight Status Updated: #{flight_request.request_number}",
        message: build_status_change_message(flight_request, old_status, new_status),
        priority: priority,
        metadata: {
          old_status: old_status,
          new_status: new_status,
          status_change_event: true
        }
      }
    )
  end

  def self.manually_trigger_flight_alerts(flight_request_id = nil)
    # For testing or manual triggering
    FlightAlertCheckerJob.perform_now
  end

  private

  def self.should_notify_status_change?(old_status, new_status)
    # Notify on significant status changes
    significant_changes = [
      ['sent', 'received'],
      ['received', 'under_review'],
      ['under_review', 'under_process'],
      ['under_process', 'completed'],
      ['under_process', 'unable'],
      [nil, 'sent']
    ]

    significant_changes.include?([old_status, new_status])
  end

  def self.get_status_change_recipients(flight_request, new_status)
    recipients = []
    
    case new_status
    when 'received', 'under_review'
      # Notify operations staff
      recipients += User.where(role: [:operations_staff, :operations_admin])
    when 'completed', 'unable'
      # Notify source of request
      recipients << flight_request.source_of_request_user if flight_request.source_of_request_user
    end

    recipients.compact.uniq
  end

  def self.determine_status_change_priority(new_status)
    case new_status
    when 'received' then :low
    when 'under_review' then :medium
    when 'under_process' then :high
    when 'completed' then :low
    when 'unable' then :high
    else :medium
    end
  end

  def self.build_status_change_message(flight_request, old_status, new_status)
    first_leg = flight_request.flight_request_legs.order(:departure_time).first
    
    <<~MESSAGE
      Flight Request #{flight_request.request_number} status has been updated.
      
      Previous Status: #{old_status&.humanize || 'None'}
      New Status: #{new_status.humanize}
      
      VIP: #{flight_request.vip_profile.codename}
      Flight Date: #{flight_request.flight_date}
      #{if first_leg
        "Route: #{first_leg.departure_airport} → #{first_leg.arrival_airport}"
      end}
      Passengers: #{flight_request.number_of_passengers}
      
      #{status_change_action_message(new_status)}
    MESSAGE
  end

  def self.status_change_action_message(status)
    case status
    when 'received'
      "This request is now ready for review by operations staff."
    when 'under_review'
      "This request is currently being reviewed."
    when 'under_process'
      "This request is being processed. Flight arrangements are being made."
    when 'completed'
      "This request has been completed successfully. Flight details are finalized."
    when 'unable'
      "This request could not be processed. Please review the details and contact operations if needed."
    else
      "Please review this request in the Presidential Flight Management System."
    end
  end
end
