require "test_helper"

class AircraftAvailabilityServiceTest < ActiveSupport::TestCase
  setup do
    # Clean up aircraft before each test
    Aircraft.destroy_all
  end

  test "should seed sample aircraft successfully" do
    result = AircraftAvailabilityService.seed_sample_aircraft
    
    assert result[:created] > 0
    assert_equal 0, result[:updated]
    assert_equal result[:created], Aircraft.count
  end

  test "should update existing aircraft when seeding again" do
    # First seeding
    AircraftAvailabilityService.seed_sample_aircraft
    initial_count = Aircraft.count
    
    # Second seeding should update existing aircraft
    result = AircraftAvailabilityService.seed_sample_aircraft
    
    assert_equal 0, result[:created]
    assert result[:updated] > 0
    assert_equal initial_count, Aircraft.count
  end

  test "should check availability with valid parameters" do
    AircraftAvailabilityService.seed_sample_aircraft
    
    result = AircraftAvailabilityService.check_availability(
      departure_date: "2024-12-25",
      departure_time: "14:00",
      passenger_count: 8
    )
    
    assert result[:success]
    assert result.key?(:available)
    assert result[:checked_at].present?
  end

  test "should return aircraft when available" do
    AircraftAvailabilityService.seed_sample_aircraft
    
    result = AircraftAvailabilityService.check_availability(
      departure_date: "2024-12-25",
      departure_time: "14:00",
      passenger_count: 4  # Small number to ensure availability
    )
    
    assert result[:success]
    
    if result[:available]
      assert result[:recommended_aircraft].present?
      assert result[:all_available_aircraft].is_a?(Array)
      assert result[:aircraft_count] > 0
    end
  end

  test "should filter by aircraft type" do
    AircraftAvailabilityService.seed_sample_aircraft
    
    result = AircraftAvailabilityService.check_availability(
      departure_date: "2024-12-25",
      departure_time: "14:00",
      passenger_count: 8,
      aircraft_type: "Gulfstream G650"
    )
    
    assert result[:success]
    
    if result[:available] && result[:all_available_aircraft].present?
      result[:all_available_aircraft].each do |aircraft|
        assert_equal "Gulfstream G650", aircraft[:aircraft_type]
      end
    end
  end

  test "should prefer aircraft at departure airport" do
    AircraftAvailabilityService.seed_sample_aircraft
    
    result = AircraftAvailabilityService.check_availability(
      departure_date: "2024-12-25",
      departure_time: "14:00",
      passenger_count: 8,
      departure_airport: "DXB"
    )
    
    assert result[:success]
    
    if result[:available] && result[:recommended_aircraft].present?
      # The recommended aircraft should have a high availability score
      assert result[:recommended_aircraft][:availability_score] > 100
    end
  end

  test "should include flight duration when arrival time provided" do
    AircraftAvailabilityService.seed_sample_aircraft
    
    result = AircraftAvailabilityService.check_availability(
      departure_date: "2024-12-25",
      departure_time: "14:00",
      arrival_date: "2024-12-25",
      arrival_time: "18:00",
      passenger_count: 8
    )
    
    assert result[:success]
    assert result[:flight_details].present?
    assert result[:flight_details][:departure].present?
    assert result[:flight_details][:arrival].present?
    assert result[:flight_details][:duration_estimate].present?
    assert_includes result[:flight_details][:duration_estimate], "4.0 hours"
  end

  test "should return error for missing departure date" do
    result = AircraftAvailabilityService.check_availability(
      departure_time: "14:00",
      passenger_count: 8
    )
    
    assert_not result[:success]
    assert result[:errors].include?("Departure date is required")
  end

  test "should return error for missing departure time" do
    result = AircraftAvailabilityService.check_availability(
      departure_date: "2024-12-25",
      passenger_count: 8
    )
    
    assert_not result[:success]
    assert result[:errors].include?("Departure time is required")
  end

  test "should return error for missing passenger count" do
    result = AircraftAvailabilityService.check_availability(
      departure_date: "2024-12-25",
      departure_time: "14:00"
    )
    
    assert_not result[:success]
    assert result[:errors].include?("Passenger count is required")
  end

  test "should return error for invalid passenger count" do
    result = AircraftAvailabilityService.check_availability(
      departure_date: "2024-12-25",
      departure_time: "14:00",
      passenger_count: 0
    )
    
    assert_not result[:success]
    assert result[:errors].include?("Passenger count must be greater than 0")
  end

  test "should return error for invalid date format" do
    result = AircraftAvailabilityService.check_availability(
      departure_date: "invalid-date",
      departure_time: "14:00",
      passenger_count: 8
    )
    
    assert_not result[:success]
    assert result[:errors].include?("Invalid departure date format")
  end

  test "should return error for invalid time format" do
    result = AircraftAvailabilityService.check_availability(
      departure_date: "2024-12-25",
      departure_time: "invalid-time",
      passenger_count: 8
    )
    
    assert_not result[:success]
    assert result[:errors].include?("Invalid departure time format")
  end

  test "should handle no available aircraft scenario" do
    # Don't seed any aircraft, or create aircraft that are all unavailable
    Aircraft.create!(
      tail_number: "TEST-001",
      aircraft_type: "Test Aircraft",
      capacity: 4,
      operational_status: :maintenance,
      maintenance_status: :major_overhaul,
      home_base: "DXB"
    )
    
    result = AircraftAvailabilityService.check_availability(
      departure_date: "2024-12-25",
      departure_time: "14:00",
      passenger_count: 8
    )
    
    assert result[:success]
    assert_not result[:available]
    assert result[:message].present?
    assert result[:suggestions].is_a?(Array)
  end

  test "should filter by minimum capacity" do
    AircraftAvailabilityService.seed_sample_aircraft
    
    # Request more passengers than some aircraft can handle
    result = AircraftAvailabilityService.check_availability(
      departure_date: "2024-12-25",
      departure_time: "14:00",
      passenger_count: 15  # More than Gulfstream G650 capacity (8)
    )
    
    assert result[:success]
    
    if result[:available] && result[:all_available_aircraft].present?
      result[:all_available_aircraft].each do |aircraft|
        assert aircraft[:capacity] >= 15
      end
    end
  end
end
