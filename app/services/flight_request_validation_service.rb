class FlightRequestValidationService
  attr_reader :flight_request, :errors

  def initialize(flight_request)
    @flight_request = flight_request
    @errors = []
  end

  def validate_all
    validate_date_range
    validate_airport_codes
    validate_time_format
    validate_passenger_limits
    validate_time_logic
    validate_business_rules

    errors.empty?
  end

  def validate_for_creation
    validate_all && validate_creation_specific_rules
  end

  def validate_for_update
    validate_all && validate_update_specific_rules
  end

  private

  def validate_date_range
    return unless flight_request.flight_date

    if flight_request.flight_date < Date.current
      errors << "Flight date cannot be in the past"
    end

    # Reasonable future range (e.g., 2 years)
    if flight_request.flight_date > Date.current + 2.years
      errors << "Flight date cannot be more than 2 years in the future"
    end
  end

  def validate_airport_codes
    %w[departure_airport_code arrival_airport_code].each do |field|
      code = flight_request.send(field)
      next unless code

      unless valid_airport_code?(code)
        errors << "#{field.humanize} must be a valid IATA airport code"
      end
    end
  end

  def validate_time_format
    %w[departure_time arrival_time].each do |field|
      time = flight_request.send(field)
      next unless time

      # Time fields in Rails are stored as Time objects, not strings
      # Skip this validation for Time objects since they're already valid
      next if time.is_a?(Time)

      unless valid_time_format?(time)
        errors << "#{field.humanize} must be in 24-hour format (HH:MM)"
      end
    end
  end

  def validate_passenger_limits
    return unless flight_request.number_of_passengers

    if flight_request.number_of_passengers < 1
      errors << "Number of passengers must be at least 1"
    end

    if flight_request.number_of_passengers > 50  # Reasonable limit
      errors << "Number of passengers cannot exceed 50"
    end
  end

  def validate_time_logic
    departure_time = flight_request.departure_time
    arrival_time = flight_request.arrival_time

    # Ensure only one time is specified (business rule from brief)
    if departure_time.present? && arrival_time.present?
      errors << "Please specify either departure time OR arrival time, not both"
    end

    if departure_time.blank? && arrival_time.blank?
      errors << "Either departure time or arrival time must be specified"
    end
  end

  def validate_business_rules
    validate_conflict_detection
    validate_aircraft_availability
    validate_security_clearance
    validate_destination_restrictions
  end

  def validate_creation_specific_rules
    # Additional rules that only apply during creation
    validate_vip_profile_authorization
    true
  end

  def validate_update_specific_rules
    # Additional rules that only apply during updates
    validate_status_transition_rules
    true
  end

  def validate_conflict_detection
    return unless flight_request.flight_date && flight_request.vip_profile

    # Check for overlapping requests for the same VIP
    conflicting_requests = FlightRequest.where(vip_profile: flight_request.vip_profile)
                                      .where(flight_date: flight_request.flight_date)
                                      .where.not(id: flight_request.id)
                                      .where.not(status: [ :done, :unable ])

    if conflicting_requests.exists?
      errors << "Another flight request already exists for this VIP on the same date"
    end
  end

  def validate_aircraft_availability
    # Placeholder for aircraft availability checking
    # This would integrate with external aircraft scheduling systems
    return unless flight_request.flight_date

    # Example business logic:
    # - Check if any aircraft is available for the requested date/time
    # - Consider aircraft maintenance schedules
    # - Account for crew availability

    # For now, just a basic check
    if weekend_restriction_applies?
      errors << "Weekend flights require special authorization"
    end
  end

  def validate_security_clearance
    return unless flight_request.vip_profile

    # Check if VIP has appropriate security clearance for the destination
    if restricted_destination? && !adequate_security_clearance?
      errors << "Destination requires higher security clearance level"
    end
  end

  def validate_destination_restrictions
    return unless flight_request.arrival_airport_code

    # Check for destination restrictions
    if blacklisted_destination?
      errors << "Flights to this destination are currently restricted"
    end

    if requires_special_authorization?
      errors << "This destination requires special authorization"
    end
  end

  def validate_vip_profile_authorization
    return unless flight_request.source_of_request_user && flight_request.vip_profile

    # Check if the source user is authorized to make requests for this VIP
    unless authorized_for_vip?
      errors << "You are not authorized to make requests for this VIP profile"
    end
  end

  def validate_status_transition_rules
    return unless flight_request.status_changed?

    old_status = flight_request.status_was
    new_status = flight_request.status

    unless valid_status_transition?(old_status, new_status)
      errors << "Invalid status transition from #{old_status} to #{new_status}"
    end
  end

  # Helper methods for validation logic

  def valid_airport_code?(code)
    # Basic IATA code validation (3 uppercase letters)
    return false unless code.is_a?(String)

    code.match?(/\A[A-Z]{3}\z/)

    # In a real implementation, you'd check against a database of valid IATA codes
    # Airport.exists?(iata_code: code)
  end

  def valid_time_format?(time)
    return false unless time.is_a?(String)

    time.match?(/\A([01]?[0-9]|2[0-3]):[0-5][0-9]\z/)
  end

  def weekend_restriction_applies?
    return false unless flight_request.flight_date

    flight_request.flight_date.saturday? || flight_request.flight_date.sunday?
  end

  def restricted_destination?
    # Example restricted destinations
    restricted_codes = %w[DME SVO LED]  # Moscow airports as example
    restricted_codes.include?(flight_request.arrival_airport_code)
  end

  def adequate_security_clearance?
    return false unless flight_request.vip_profile

    # Check VIP security clearance level
    flight_request.vip_profile.security_clearance_level >= 3
  end

  def blacklisted_destination?
    # Example blacklisted destinations
    blacklisted_codes = %w[KBL DAM BGW]  # Example conflict zones
    blacklisted_codes.include?(flight_request.arrival_airport_code)
  end

  def requires_special_authorization?
    # Destinations requiring special authorization
    special_auth_codes = %w[PEK PVG ICN NRT]  # Example: Asia-Pacific regions
    special_auth_codes.include?(flight_request.arrival_airport_code)
  end

  def authorized_for_vip?
    VipSourcesRelationship.exists?(
      vip_profile: flight_request.vip_profile,
      source_of_request_user: flight_request.source_of_request_user,
      active: true
    )
  end

  def valid_status_transition?(from_status, to_status)
    # Define valid status transitions
    valid_transitions = {
      "sent" => %w[received unable],
      "received" => %w[under_review unable],
      "under_review" => %w[under_process unable],
      "under_process" => %w[done unable],
      "done" => [],  # Final status
      "unable" => []  # Final status
    }

    valid_transitions[from_status]&.include?(to_status) || false
  end
end
