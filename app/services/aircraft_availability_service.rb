class AircraftAvailabilityService
  class << self
    def check_availability(departure_date: nil, departure_time: nil, arrival_date: nil, arrival_time: nil, passenger_count: nil, aircraft_type: nil, departure_airport: nil, arrival_airport: nil)
      # Input validation
      errors = validate_inputs(departure_date, departure_time, passenger_count)
      return error_response(errors) if errors.any?

      # Parse dates and times
      departure_datetime = parse_datetime(departure_date, departure_time)
      arrival_datetime = parse_datetime(arrival_date, arrival_time) if arrival_date && arrival_time

      # Find suitable aircraft
      available_aircraft = find_available_aircraft(
        departure_datetime: departure_datetime,
        arrival_datetime: arrival_datetime,
        passenger_count: passenger_count,
        aircraft_type: aircraft_type,
        departure_airport: departure_airport
      )

      # Build response
      build_availability_response(available_aircraft, departure_datetime, arrival_datetime)
    end

    def seed_sample_aircraft
      sample_aircraft = [
        { tail_number: 'A6-PF1', aircraft_type: 'Boeing 777-300ER', capacity: 12, operational_status: 'active', maintenance_status: 'ready', home_base: 'DXB' },
        { tail_number: 'A6-PF2', aircraft_type: 'Boeing 777-300ER', capacity: 12, operational_status: 'active', maintenance_status: 'ready', home_base: 'AUH' },
        { tail_number: 'A6-PF3', aircraft_type: 'Gulfstream G650', capacity: 8, operational_status: 'active', maintenance_status: 'ready', home_base: 'DXB' },
        { tail_number: 'A6-PF4', aircraft_type: 'Gulfstream G650', capacity: 8, operational_status: 'active', maintenance_status: 'scheduled_maintenance', home_base: 'DXB' },
        { tail_number: 'A6-PF5', aircraft_type: 'Bombardier Global 7500', capacity: 10, operational_status: 'active', maintenance_status: 'ready', home_base: 'AUH' },
        { tail_number: 'A6-PF6', aircraft_type: 'Bombardier Global 7500', capacity: 10, operational_status: 'maintenance', maintenance_status: 'unscheduled_maintenance', home_base: 'SHJ' }
      ]

      created_count = 0
      updated_count = 0

      sample_aircraft.each do |aircraft_data|
        existing_aircraft = Aircraft.find_by(tail_number: aircraft_data[:tail_number])
        
        if existing_aircraft
          existing_aircraft.update!(aircraft_data)
          updated_count += 1
        else
          Aircraft.create!(aircraft_data)
          created_count += 1
        end
      end

      { created: created_count, updated: updated_count, total: sample_aircraft.size }
    end

    private

    def validate_inputs(departure_date, departure_time, passenger_count)
      errors = []

      if departure_date.blank?
        errors << 'Departure date is required'
      elsif !valid_date?(departure_date)
        errors << 'Invalid departure date format'
      end

      if departure_time.blank?
        errors << 'Departure time is required'
      elsif !valid_time?(departure_time)
        errors << 'Invalid departure time format'
      end

      if passenger_count.blank?
        errors << 'Passenger count is required'
      elsif passenger_count.to_i <= 0
        errors << 'Passenger count must be greater than 0'
      end

      errors
    end

    def valid_date?(date_string)
      Date.parse(date_string.to_s)
      true
    rescue ArgumentError
      false
    end

    def valid_time?(time_string)
      Time.parse(time_string.to_s)
      true
    rescue ArgumentError
      false
    end

    def parse_datetime(date, time)
      return nil if date.blank? || time.blank?
      
      # Handle timezone properly
      Time.zone.parse("#{date} #{time}")
    rescue ArgumentError
      nil
    end

    def find_available_aircraft(departure_datetime:, arrival_datetime:, passenger_count:, aircraft_type:, departure_airport:)
      query = Aircraft.available.minimum_capacity(passenger_count.to_i)
      
      # Filter by aircraft type if specified
      query = query.by_type(aircraft_type) if aircraft_type.present?
      
      # Filter by home base if departure airport is specified
      query = query.by_base(departure_airport) if departure_airport.present?
      
      # For demo purposes, we'll return available aircraft
      # In a real system, this would check actual scheduling conflicts
      aircraft_list = query.limit(5).map do |aircraft|
        {
          tail_number: aircraft.tail_number,
          aircraft_type: aircraft.aircraft_type,
          capacity: aircraft.capacity,
          home_base: aircraft.home_base,
          status: aircraft.status_description,
          availability_score: calculate_availability_score(aircraft, departure_datetime, departure_airport)
        }
      end

      # Sort by availability score (higher is better)
      aircraft_list.sort_by { |a| -a[:availability_score] }
    end

    def calculate_availability_score(aircraft, departure_datetime, departure_airport)
      score = 100 # Base score

      # Prefer aircraft at the departure airport
      score += 50 if aircraft.home_base == departure_airport

      # Prefer aircraft with exact capacity match (not too oversized)
      # This is a simplified scoring system
      score += 25 if aircraft.capacity <= 15 # Prefer smaller aircraft for efficiency

      # Add randomness for demo purposes
      score += rand(1..10)

      score
    end

    def build_availability_response(available_aircraft, departure_datetime, arrival_datetime)
      if available_aircraft.any?
        {
          success: true,
          available: true,
          aircraft_count: available_aircraft.size,
          recommended_aircraft: available_aircraft.first,
          all_available_aircraft: available_aircraft,
          checked_at: Time.current.iso8601,
          flight_details: {
            departure: departure_datetime&.iso8601,
            arrival: arrival_datetime&.iso8601,
            duration_estimate: calculate_duration_estimate(departure_datetime, arrival_datetime)
          }
        }
      else
        {
          success: true,
          available: false,
          message: 'No aircraft available for the requested time and requirements',
          suggestions: [
            'Try a different departure time',
            'Consider reducing passenger count',
            'Check availability for alternative dates'
          ],
          checked_at: Time.current.iso8601
        }
      end
    end

    def calculate_duration_estimate(departure_datetime, arrival_datetime)
      return nil unless departure_datetime && arrival_datetime
      
      duration_seconds = arrival_datetime - departure_datetime
      duration_hours = (duration_seconds / 3600.0).round(2)
      "#{duration_hours} hours"
    end

    def error_response(errors)
      {
        success: false,
        errors: errors
      }
    end
  end
end
