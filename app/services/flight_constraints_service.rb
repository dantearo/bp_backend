class FlightConstraintsService
  # Restricted airports that require special clearance
  RESTRICTED_AIRPORTS = %w[
    RESTRICTED_MILITARY_BASE
    CLOSED_FOR_MAINTENANCE
  ].freeze

  # VIP security clearance levels
  SECURITY_CLEARANCES = {
    'level_1' => 'Basic clearance',
    'level_2' => 'Standard clearance',
    'level_3' => 'High security clearance',
    'level_4' => 'Maximum security clearance'
  }.freeze

  class << self
    def check_basic_constraints(departure_airport: nil, arrival_airport: nil, vip_clearance: nil)
      constraints = []
      restrictions = []
      clearances_required = []

      # Check departure airport restrictions
      if departure_airport.present?
        dep_check = check_airport_restrictions(departure_airport)
        restrictions.concat(dep_check[:restrictions]) if dep_check[:restrictions].any?
        clearances_required.concat(dep_check[:clearances_required]) if dep_check[:clearances_required].any?
      end

      # Check arrival airport restrictions
      if arrival_airport.present?
        arr_check = check_airport_restrictions(arrival_airport)
        restrictions.concat(arr_check[:restrictions]) if arr_check[:restrictions].any?
        clearances_required.concat(arr_check[:clearances_required]) if arr_check[:clearances_required].any?
      end

      # Check VIP security clearance
      if vip_clearance.present?
        clearance_check = validate_security_clearance(vip_clearance)
        constraints << clearance_check[:message] unless clearance_check[:valid]
      end

      # Check route-specific constraints
      if departure_airport.present? && arrival_airport.present?
        route_constraints = check_route_constraints(departure_airport, arrival_airport)
        constraints.concat(route_constraints)
      end

      {
        status: constraints.any? || restrictions.any? ? 'restricted' : 'clear',
        constraints: constraints,
        restrictions: restrictions,
        clearances_required: clearances_required.uniq,
        message: build_constraints_message(constraints, restrictions, clearances_required),
        checked_at: Time.current.iso8601
      }
    end

    def validate_security_clearance(clearance_level)
      if SECURITY_CLEARANCES.key?(clearance_level)
        {
          valid: true,
          level: clearance_level,
          description: SECURITY_CLEARANCES[clearance_level]
        }
      else
        {
          valid: false,
          message: 'Invalid security clearance level'
        }
      end
    end

    def check_destination_access(airport_code, vip_clearance_level)
      # Check if airport is restricted first (before looking in database)
      if RESTRICTED_AIRPORTS.include?(airport_code)
        required_clearance = determine_required_clearance(airport_code)
        
        if vip_clearance_level.present? && clearance_sufficient?(vip_clearance_level, required_clearance)
          {
            accessible: true,
            message: 'Access granted with current clearance level',
            clearance_used: vip_clearance_level
          }
        else
          {
            accessible: false,
            message: 'Insufficient security clearance for this destination',
            required_clearance: required_clearance
          }
        end
      else
        # For non-restricted airports, check if they exist and their operational status
        airport = AirportDataService.find_by_code(airport_code)
        return { accessible: false, message: 'Airport not found' } unless airport

        operational_status = AirportDataService.operational_status_check(airport_code)
        
        {
          accessible: operational_status[:status] == 'operational',
          message: operational_status[:message],
          operational_status: operational_status[:status]
        }
      end
    end

    def get_flight_restrictions(departure_airport, arrival_airport, flight_date = nil)
      restrictions = []

      # Time-based restrictions
      if flight_date.present?
        date_restrictions = check_date_restrictions(flight_date)
        restrictions.concat(date_restrictions)
      end

      # Airspace restrictions
      airspace_restrictions = check_airspace_restrictions(departure_airport, arrival_airport)
      restrictions.concat(airspace_restrictions)

      # Diplomatic restrictions (mock)
      diplomatic_restrictions = check_diplomatic_restrictions(departure_airport, arrival_airport)
      restrictions.concat(diplomatic_restrictions)

      {
        restrictions: restrictions,
        total_count: restrictions.size,
        severity_levels: restrictions.group_by { |r| r[:severity] }.transform_values(&:count)
      }
    end

    private

    def check_airport_restrictions(airport_code)
      restrictions = []
      clearances_required = []

      # Check if airport is in restricted list
      if RESTRICTED_AIRPORTS.include?(airport_code)
        restrictions << {
          type: 'restricted_airport',
          message: 'Airport requires special security clearance',
          severity: 'high'
        }
        clearances_required << determine_required_clearance(airport_code)
      end

      # Check operational status
      operational_status = AirportDataService.operational_status_check(airport_code)
      
      unless operational_status[:status] == 'operational'
        restrictions << {
          type: 'operational_restriction',
          message: operational_status[:message],
          severity: operational_status[:status] == 'closed' ? 'high' : 'medium'
        }
      end

      {
        restrictions: restrictions,
        clearances_required: clearances_required
      }
    end

    def determine_required_clearance(airport_code)
      # This would typically be based on a database or external service
      # For demo purposes, we'll use a simple mapping
      case airport_code
      when 'RESTRICTED_MILITARY_BASE'
        'level_4'
      else
        'level_2'
      end
    end

    def clearance_sufficient?(current_level, required_level)
      # Extract numeric level for comparison
      current_match = current_level.to_s.match(/\d+/)
      required_match = required_level.to_s.match(/\d+/)
      
      current_num = current_match ? current_match[0].to_i : 0
      required_num = required_match ? required_match[0].to_i : 0
      
      current_num >= required_num
    end

    def check_route_constraints(departure_airport, arrival_airport)
      constraints = []

      # Check for known problematic routes
      if departure_airport == arrival_airport
        constraints << 'Departure and arrival airports cannot be the same'
      end

      # Check for routes requiring special permissions
      if international_route?(departure_airport, arrival_airport)
        constraints << 'International flight - diplomatic clearance may be required'
      end

      constraints
    end

    def international_route?(departure_airport, arrival_airport)
      # This is a simplified check - in reality, you'd look up the countries
      # For demo purposes, we'll assume different ICAO prefixes indicate different countries
      return false if departure_airport.blank? || arrival_airport.blank?
      
      # Get the actual airport records to check their countries
      dep_airport = AirportDataService.find_by_code(departure_airport)
      arr_airport = AirportDataService.find_by_code(arrival_airport)
      
      return false unless dep_airport && arr_airport
      
      dep_airport.country != arr_airport.country
    end

    def check_date_restrictions(flight_date)
      restrictions = []
      
      begin
        date = Date.parse(flight_date.to_s)
        
        # Check if it's a weekend (might have different restrictions)
        if date.saturday? || date.sunday?
          restrictions << {
            type: 'weekend_restriction',
            message: 'Weekend flights may have limited support staff',
            severity: 'low'
          }
        end

        # Check if it's a holiday (mock data)
        if holiday_date?(date)
          restrictions << {
            type: 'holiday_restriction',
            message: 'Holiday period - limited operations',
            severity: 'medium'
          }
        end
      rescue ArgumentError
        restrictions << {
          type: 'invalid_date',
          message: 'Invalid flight date format',
          severity: 'high'
        }
      end

      restrictions
    end

    def holiday_date?(date)
      # Mock holiday checking - in reality, this would check against a holidays database
      # For demo purposes, check if it's December 25th or January 1st
      (date.month == 12 && date.day == 25) || (date.month == 1 && date.day == 1)
    end

    def check_airspace_restrictions(departure_airport, arrival_airport)
      # Mock airspace restrictions
      restrictions = []
      
      # This would typically query real airspace data
      # For demo purposes, we'll add some mock restrictions
      if departure_airport == 'DXB' && arrival_airport == 'LHR'
        restrictions << {
          type: 'airspace_congestion',
          message: 'High traffic route - expect potential delays',
          severity: 'low'
        }
      end

      restrictions
    end

    def check_diplomatic_restrictions(departure_airport, arrival_airport)
      # Mock diplomatic restrictions
      restrictions = []
      
      # This would check against real diplomatic databases
      # For demo purposes, we'll add mock restrictions
      if international_route?(departure_airport, arrival_airport)
        restrictions << {
          type: 'diplomatic_clearance',
          message: 'International route - verify diplomatic clearance',
          severity: 'medium'
        }
      end

      restrictions
    end

    def build_constraints_message(constraints, restrictions, clearances_required)
      messages = []
      
      if constraints.any?
        messages << "Constraints: #{constraints.join(', ')}"
      end
      
      if restrictions.any?
        messages << "Restrictions: #{restrictions.map { |r| r[:message] }.join(', ')}"
      end
      
      if clearances_required.any?
        messages << "Required clearances: #{clearances_required.join(', ')}"
      end
      
      if messages.empty?
        'No flight constraints detected'
      else
        messages.join(' | ')
      end
    end
  end
end
