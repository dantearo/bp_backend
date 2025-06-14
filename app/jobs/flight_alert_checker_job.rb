class FlightAlertCheckerJob < ApplicationJob
  queue_as :alerts

  def perform
    check_timeline_alerts
    schedule_escalations
  end

  private

  def check_timeline_alerts
    pending_flights = FlightRequest.pending.joins(:flight_request_legs)
                                         .where(flight_request_legs: { departure_time: 1.hour.from_now..3.days.from_now })
                                         .distinct

    pending_flights.find_each do |flight_request|
      check_flight_alerts(flight_request)
    end
  end

  def check_flight_alerts(flight_request)
    return unless flight_request.flight_request_legs.exists?

    earliest_departure = flight_request.flight_request_legs.minimum(:departure_time)
    return unless earliest_departure

    hours_until_flight = ((earliest_departure - Time.current) / 1.hour).round(1)
    alert_thresholds = [72, 48, 24, 12, 6]

    alert_thresholds.each do |threshold|
      next if hours_until_flight > threshold || hours_until_flight <= 0

      # Check if alert already exists for this threshold
      existing_alert = flight_request.alerts.timeline
                                           .where(metadata: { threshold: threshold })
                                           .first

      next if existing_alert

      create_timeline_alert(flight_request, threshold, hours_until_flight)
    end
  end

  def create_timeline_alert(flight_request, threshold, hours_until_flight)
    priority = determine_priority(threshold)
    
    # Notify operations staff
    operations_users = User.where(role: [:operations_staff, :operations_admin])
    
    operations_users.find_each do |user|
      alert = flight_request.alerts.create!(
        alert_type: :timeline,
        user: user,
        title: "Flight Alert: #{threshold}h until departure",
        message: build_alert_message(flight_request, threshold, hours_until_flight),
        priority: priority,
        status: :active,
        metadata: { 
          threshold: threshold,
          hours_until_flight: hours_until_flight,
          flight_request_id: flight_request.id 
        }
      )

      # Queue notification delivery
      NotificationDeliveryJob.perform_later(alert.id)
    end

    # Also notify the source of request
    if flight_request.source_of_request_user
      alert = flight_request.alerts.create!(
        alert_type: :timeline,
        user: flight_request.source_of_request_user,
        title: "Flight Status Reminder: #{threshold}h until departure",
        message: build_requester_alert_message(flight_request, threshold),
        priority: priority,
        status: :active,
        metadata: { 
          threshold: threshold,
          hours_until_flight: hours_until_flight,
          flight_request_id: flight_request.id 
        }
      )

      NotificationDeliveryJob.perform_later(alert.id)
    end
  end

  def build_alert_message(flight_request, threshold, hours_until_flight)
    first_leg = flight_request.flight_request_legs.order(:departure_time).first
    
    <<~MESSAGE
      Flight Request #{flight_request.request_number} requires attention.
      
      Time until departure: #{hours_until_flight.round(1)} hours
      Status: #{flight_request.status.humanize}
      VIP: #{flight_request.vip_profile.codename}
      Route: #{first_leg&.departure_airport_code} → #{first_leg&.arrival_airport_code}
      Passengers: #{flight_request.number_of_passengers}
      
      Please review and process this request.
    MESSAGE
  end

  def build_requester_alert_message(flight_request, threshold)
    first_leg = flight_request.flight_request_legs.order(:departure_time).first
    
    <<~MESSAGE
      Your flight request #{flight_request.request_number} is #{threshold} hours from departure.
      
      Current Status: #{flight_request.status.humanize}
      Route: #{first_leg&.departure_airport_code} → #{first_leg&.arrival_airport_code}
      Departure: #{first_leg&.departure_time&.strftime('%B %d, %Y at %H:%M')}
      
      Please ensure all required documentation is submitted.
    MESSAGE
  end

  def determine_priority(threshold)
    case threshold
    when 72 then :low
    when 48 then :medium
    when 24 then :high
    when 12 then :urgent
    when 6 then :critical
    else :medium
    end
  end

  def schedule_escalations
    # Schedule escalation for unacknowledged critical alerts older than 1 hour
    unacknowledged_alerts = Alert.unacknowledged
                                .where(priority: :critical)
                                .where('created_at < ?', 1.hour.ago)

    unacknowledged_alerts.find_each do |alert|
      AlertEscalationJob.perform_later(alert.id)
    end
  end
end
