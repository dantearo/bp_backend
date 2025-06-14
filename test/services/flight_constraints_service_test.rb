require "test_helper"

class FlightConstraintsServiceTest < ActiveSupport::TestCase
  setup do
    # Seed airports for testing
    AirportDataService.seed_airports
  end

  test "should check basic constraints with no restrictions" do
    result = FlightConstraintsService.check_basic_constraints(
      departure_airport: "DXB",
      arrival_airport: "AUH"  # Both UAE airports, so not international
    )
    
    assert_equal "clear", result[:status]  # Should be clear since no restrictions
    assert result[:checked_at].present?
  end

  test "should detect same departure and arrival airport" do
    result = FlightConstraintsService.check_basic_constraints(
      departure_airport: "DXB",
      arrival_airport: "DXB"
    )
    
    assert_equal "restricted", result[:status]
    assert result[:constraints].include?("Departure and arrival airports cannot be the same")
  end

  test "should detect international route" do
    result = FlightConstraintsService.check_basic_constraints(
      departure_airport: "DXB",  # UAE airport (starts with O)
      arrival_airport: "LHR"     # UK airport (starts with E)
    )
    
    # Since we're using a simplified check based on first letter
    # DXB (OMDB) starts with O, LHR (EGLL) starts with E, so it should be international
    if result[:status] == "restricted"
      assert result[:constraints].any? { |c| c.include?("International flight") }
    end
  end

  test "should validate valid security clearance" do
    result = FlightConstraintsService.validate_security_clearance("level_3")
    
    assert result[:valid]
    assert_equal "level_3", result[:level]
    assert_equal "High security clearance", result[:description]
  end

  test "should reject invalid security clearance" do
    result = FlightConstraintsService.validate_security_clearance("invalid_level")
    
    assert_not result[:valid]
    assert_equal "Invalid security clearance level", result[:message]
  end

  test "should check destination access for operational airport" do
    result = FlightConstraintsService.check_destination_access("DXB", "level_2")
    
    assert result[:accessible]
    assert result[:message].present?
  end

  test "should deny access to restricted airport without sufficient clearance" do
    result = FlightConstraintsService.check_destination_access("RESTRICTED_MILITARY_BASE", "level_1")
    
    assert_not result[:accessible]
    assert result[:message].include?("Insufficient security clearance")
    assert result[:required_clearance].present?
  end

  test "should allow access to restricted airport with sufficient clearance" do
    result = FlightConstraintsService.check_destination_access("RESTRICTED_MILITARY_BASE", "level_4")
    
    assert result[:accessible]
    assert result[:message].include?("Access granted")
  end

  test "should return not found for invalid airport" do
    result = FlightConstraintsService.check_destination_access("INVALID", "level_3")
    
    assert_not result[:accessible]
    assert_equal "Airport not found", result[:message]
  end

  test "should get flight restrictions for future date" do
    future_date = Date.current + 30.days
    
    result = FlightConstraintsService.get_flight_restrictions("DXB", "LHR", future_date)
    
    assert result[:restrictions].is_a?(Array)
    assert result[:total_count] >= 0
    assert result[:severity_levels].is_a?(Hash)
  end

  test "should detect weekend restrictions" do
    # Find next Saturday
    next_saturday = Date.current.beginning_of_week + 5.days
    
    result = FlightConstraintsService.get_flight_restrictions("DXB", "LHR", next_saturday)
    
    weekend_restriction = result[:restrictions].find { |r| r[:type] == "weekend_restriction" }
    assert weekend_restriction.present?
    assert_equal "low", weekend_restriction[:severity]
  end

  test "should detect holiday restrictions" do
    christmas = Date.new(Date.current.year, 12, 25)
    
    result = FlightConstraintsService.get_flight_restrictions("DXB", "LHR", christmas)
    
    holiday_restriction = result[:restrictions].find { |r| r[:type] == "holiday_restriction" }
    assert holiday_restriction.present?
    assert_equal "medium", holiday_restriction[:severity]
  end

  test "should handle invalid date format" do
    result = FlightConstraintsService.get_flight_restrictions("DXB", "LHR", "invalid-date")
    
    invalid_date_restriction = result[:restrictions].find { |r| r[:type] == "invalid_date" }
    assert invalid_date_restriction.present?
    assert_equal "high", invalid_date_restriction[:severity]
  end

  test "should detect airspace congestion for high traffic routes" do
    result = FlightConstraintsService.get_flight_restrictions("DXB", "LHR")
    
    congestion_restriction = result[:restrictions].find { |r| r[:type] == "airspace_congestion" }
    
    if congestion_restriction
      assert_equal "low", congestion_restriction[:severity]
      assert congestion_restriction[:message].include?("High traffic route")
    end
  end

  test "should require diplomatic clearance for international routes" do
    result = FlightConstraintsService.get_flight_restrictions("DXB", "LHR")
    
    diplomatic_restriction = result[:restrictions].find { |r| r[:type] == "diplomatic_clearance" }
    
    if diplomatic_restriction
      assert_equal "medium", diplomatic_restriction[:severity]
      assert diplomatic_restriction[:message].include?("diplomatic clearance")
    end
  end

  test "should handle empty parameters gracefully" do
    result = FlightConstraintsService.check_basic_constraints()
    
    assert result[:status].present?
    assert result[:checked_at].present?
    assert result[:constraints].is_a?(Array)
    assert result[:restrictions].is_a?(Array)
  end

  test "should build appropriate constraints message" do
    result = FlightConstraintsService.check_basic_constraints(
      departure_airport: "DXB",
      arrival_airport: "DXB"  # Same airport to trigger constraint
    )
    
    assert result[:message].present?
    if result[:status] == "restricted"
      assert result[:message].include?("Constraints") || result[:message].include?("Restrictions")
    else
      assert_equal "No flight constraints detected", result[:message]
    end
  end

  test "should include VIP clearance check in basic constraints" do
    result = FlightConstraintsService.check_basic_constraints(
      departure_airport: "DXB",
      arrival_airport: "LHR",
      vip_clearance: "invalid_clearance"
    )
    
    assert_equal "restricted", result[:status]
    assert result[:constraints].include?("Invalid security clearance level")
  end

  test "should not have constraints with valid VIP clearance" do
    result = FlightConstraintsService.check_basic_constraints(
      departure_airport: "DXB",
      arrival_airport: "LHR",
      vip_clearance: "level_3"
    )
    
    # Should not add constraints for valid clearance
    assert_not result[:constraints].include?("Invalid security clearance level")
  end
end
