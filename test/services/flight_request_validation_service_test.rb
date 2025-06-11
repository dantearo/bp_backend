require "test_helper"

class FlightRequestValidationServiceTest < ActiveSupport::TestCase
  setup do
    @vip_profile = vip_profiles(:one)
    @source_user = users(:source_user)

    # Create relationship between source user and VIP profile
    VipSourcesRelationship.find_or_create_by!(
      vip_profile: @vip_profile,
      source_of_request_user: @source_user,
      delegation_level: "full",
      approval_authority: "all",
      status: :active
    )

    @flight_request = FlightRequest.new(
      vip_profile: @vip_profile,
      source_of_request_user: @source_user,
      flight_date: Date.tomorrow,
      departure_airport_code: "DXB",
      arrival_airport_code: "JFK",
      departure_time: "08:00",
      number_of_passengers: 3
    )
  end

  test "validates valid flight request" do
    # Use a unique date to avoid conflicts with fixture data
    @flight_request.flight_date = Date.current + 10.days
    service = FlightRequestValidationService.new(@flight_request)
    assert service.validate_all, "Validation failed with errors: #{service.errors.join(', ')}"
    assert_empty service.errors
  end

  test "rejects past flight dates" do
    @flight_request.flight_date = Date.yesterday
    service = FlightRequestValidationService.new(@flight_request)

    refute service.validate_all
    assert_includes service.errors, "Flight date cannot be in the past"
  end

  test "rejects invalid airport codes" do
    @flight_request.departure_airport_code = "INVALID"
    service = FlightRequestValidationService.new(@flight_request)

    refute service.validate_all
    assert_includes service.errors, "Departure airport code must be a valid IATA airport code"
  end

  test "rejects invalid time format" do
    # Test with a string that looks like time but is invalid
    # We'll temporarily stub the accessor to return a string
    @flight_request.define_singleton_method(:departure_time) { "25:00" }
    @flight_request.arrival_time = nil
    service = FlightRequestValidationService.new(@flight_request)

    refute service.validate_all
    assert_includes service.errors, "Departure time must be in 24-hour format (HH:MM)"
  end

  test "rejects both departure and arrival times" do
    @flight_request.departure_time = "08:00"
    @flight_request.arrival_time = "18:00"
    service = FlightRequestValidationService.new(@flight_request)

    refute service.validate_all
    assert_includes service.errors, "Please specify either departure time OR arrival time, not both"
  end

  test "requires either departure or arrival time" do
    @flight_request.departure_time = nil
    @flight_request.arrival_time = nil
    service = FlightRequestValidationService.new(@flight_request)

    refute service.validate_all
    assert_includes service.errors, "Either departure time or arrival time must be specified"
  end

  test "validates passenger limits" do
    @flight_request.number_of_passengers = 0
    service = FlightRequestValidationService.new(@flight_request)

    refute service.validate_all
    assert_includes service.errors, "Number of passengers must be at least 1"

    @flight_request.number_of_passengers = 100
    service = FlightRequestValidationService.new(@flight_request)

    refute service.validate_all
    assert_includes service.errors, "Number of passengers cannot exceed 50"
  end

  test "validates future date limits" do
    @flight_request.flight_date = Date.current + 3.years
    service = FlightRequestValidationService.new(@flight_request)

    refute service.validate_all
    assert_includes service.errors, "Flight date cannot be more than 2 years in the future"
  end

  test "detects conflicting requests" do
    # Create a flight request with a unique date for this test
    conflict_date = Date.current + 5.days
    @flight_request.flight_date = conflict_date

    # Create an existing request for the same VIP and date
    existing_request = FlightRequest.create!(
      vip_profile: @vip_profile,
      source_of_request_user: @source_user,
      flight_date: conflict_date,
      departure_airport_code: "AUH",
      arrival_airport_code: "CDG",
      departure_time: "10:00",
      number_of_passengers: 2,
      status: "sent"
    )

    service = FlightRequestValidationService.new(@flight_request)

    refute service.validate_all
    assert_includes service.errors, "Another flight request already exists for this VIP on the same date"
  end

  test "accepts valid IATA airport codes" do
    valid_codes = %w[DXB JFK LAX LHR CDG NRT]

    valid_codes.each do |code|
      @flight_request.flight_date = Date.current + 15.days  # Use unique date
      @flight_request.departure_airport_code = code
      @flight_request.arrival_airport_code = code == "DXB" ? "JFK" : "DXB"  # Ensure different airports

      service = FlightRequestValidationService.new(@flight_request)
      assert service.validate_all, "#{code} should be valid. Errors: #{service.errors.join(', ')}"
    end
  end

  test "accepts valid time formats" do
    valid_times = %w[00:00 08:30 12:00 23:59]

    valid_times.each_with_index do |time, index|
      # Use a weekday and unique date for each test
      test_date = Date.current + (21 + index).days
      test_date = test_date.next_occurring(:monday) if test_date.saturday? || test_date.sunday?

      @flight_request.flight_date = test_date
      @flight_request.departure_time = time
      @flight_request.arrival_time = nil

      service = FlightRequestValidationService.new(@flight_request)
      assert service.validate_all, "#{time} should be valid. Errors: #{service.errors.join(', ')}"
    end
  end
end
