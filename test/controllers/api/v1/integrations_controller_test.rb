require "test_helper"

class Api::V1::IntegrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Seed test data
    AirportDataService.seed_airports
    AircraftAvailabilityService.seed_sample_aircraft
  end

  test "should check aircraft availability with valid parameters" do
    post "/api/v1/integrations/check_availability", params: {
      departure_date: "2024-12-25",
      departure_time: "14:00",
      passenger_count: 8,
      departure_airport: "DXB",
      arrival_airport: "LHR"
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert json.key?("available")
    assert json["checked_at"].present?
    assert json["integration_checks"].present?
    
    # Check integration checks structure
    assert json["integration_checks"]["departure_airport"].present?
    assert json["integration_checks"]["arrival_airport"].present?
    assert json["integration_checks"]["flight_constraints"].present?
  end

  test "should check availability with minimal parameters" do
    post "/api/v1/integrations/check_availability", params: {
      departure_date: "2024-12-25",
      departure_time: "14:00",
      passenger_count: 4
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert json.key?("available")
  end

  test "should return error for missing departure date" do
    post "/api/v1/integrations/check_availability", params: {
      departure_time: "14:00",
      passenger_count: 8
    }
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    
    assert_not json["success"]
    assert json["errors"].include?("Departure date is required")
  end

  test "should return error for missing departure time" do
    post "/api/v1/integrations/check_availability", params: {
      departure_date: "2024-12-25",
      passenger_count: 8
    }
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    
    assert_not json["success"]
    assert json["errors"].include?("Departure time is required")
  end

  test "should return error for missing passenger count" do
    post "/api/v1/integrations/check_availability", params: {
      departure_date: "2024-12-25",
      departure_time: "14:00"
    }
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    
    assert_not json["success"]
    assert json["errors"].include?("Passenger count is required")
  end

  test "should return error for invalid passenger count" do
    post "/api/v1/integrations/check_availability", params: {
      departure_date: "2024-12-25",
      departure_time: "14:00",
      passenger_count: 0
    }
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    
    assert_not json["success"]
    assert json["errors"].include?("Passenger count must be greater than 0")
  end

  test "should return error for invalid date format" do
    post "/api/v1/integrations/check_availability", params: {
      departure_date: "invalid-date",
      departure_time: "14:00",
      passenger_count: 8
    }
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    
    assert_not json["success"]
    assert json["errors"].include?("Invalid departure date format")
  end

  test "should return error for invalid time format" do
    post "/api/v1/integrations/check_availability", params: {
      departure_date: "2024-12-25",
      departure_time: "invalid-time",
      passenger_count: 8
    }
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    
    assert_not json["success"]
    assert json["errors"].include?("Invalid departure time format")
  end

  test "should include aircraft information when available" do
    post "/api/v1/integrations/check_availability", params: {
      departure_date: "2024-12-25",
      departure_time: "14:00",
      passenger_count: 8,
      departure_airport: "DXB"
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    
    if json["available"]
      assert json["recommended_aircraft"].present?
      assert json["recommended_aircraft"]["tail_number"].present?
      assert json["recommended_aircraft"]["aircraft_type"].present?
      assert json["all_available_aircraft"].is_a?(Array)
    end
  end

  test "should filter by aircraft type" do
    post "/api/v1/integrations/check_availability", params: {
      departure_date: "2024-12-25",
      departure_time: "14:00",
      passenger_count: 8,
      aircraft_type: "Gulfstream G650"
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    
    if json["available"] && json["all_available_aircraft"].present?
      json["all_available_aircraft"].each do |aircraft|
        assert_equal "Gulfstream G650", aircraft["aircraft_type"]
      end
    end
  end

  test "should include flight details when both departure and arrival times provided" do
    post "/api/v1/integrations/check_availability", params: {
      departure_date: "2024-12-25",
      departure_time: "14:00",
      arrival_date: "2024-12-25",
      arrival_time: "18:00",
      passenger_count: 8
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert json["flight_details"].present?
    assert json["flight_details"]["departure"].present?
    assert json["flight_details"]["arrival"].present?
    assert json["flight_details"]["duration_estimate"].present?
  end
end
