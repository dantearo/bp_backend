require "test_helper"

class AirportDataServiceTest < ActiveSupport::TestCase
  setup do
    # Clean up airports before each test
    Airport.destroy_all
  end

  test "should seed airports successfully" do
    result = AirportDataService.seed_airports
    
    assert_equal AirportDataService::SAMPLE_AIRPORTS.size, result[:created]
    assert_equal 0, result[:updated]
    assert_equal AirportDataService::SAMPLE_AIRPORTS.size, result[:total]
    assert_equal AirportDataService::SAMPLE_AIRPORTS.size, Airport.count
  end

  test "should update existing airports when seeding again" do
    # First seeding
    AirportDataService.seed_airports
    initial_count = Airport.count
    
    # Second seeding should update existing airports
    result = AirportDataService.seed_airports
    
    assert_equal 0, result[:created]
    assert_equal AirportDataService::SAMPLE_AIRPORTS.size, result[:updated]
    assert_equal initial_count, Airport.count
  end

  test "should search airports by name" do
    AirportDataService.seed_airports
    
    results = AirportDataService.search_airports("Dubai")
    
    assert results.any?
    assert results.all? { |airport| airport.city.downcase.include?("dubai") || airport.name.downcase.include?("dubai") }
  end

  test "should search airports by IATA code" do
    AirportDataService.seed_airports
    
    results = AirportDataService.search_airports("DXB")
    
    assert results.any?
    assert results.any? { |airport| airport.iata_code == "DXB" }
  end

  test "should search airports by ICAO code" do
    AirportDataService.seed_airports
    
    results = AirportDataService.search_airports("OMDB")
    
    assert results.any?
    assert results.any? { |airport| airport.icao_code == "OMDB" }
  end

  test "should limit search results" do
    AirportDataService.seed_airports
    
    results = AirportDataService.search_airports("", limit: 3)
    
    assert_equal 3, results.size
  end

  test "should return empty array for non-existent search" do
    AirportDataService.seed_airports
    
    results = AirportDataService.search_airports("NONEXISTENT")
    
    assert_empty results
  end

  test "should return all operational airports when query is blank" do
    AirportDataService.seed_airports
    
    results = AirportDataService.search_airports("")
    
    assert results.any?
    assert results.all?(&:active?)
  end

  test "should find airport by IATA code" do
    AirportDataService.seed_airports
    
    airport = AirportDataService.find_by_code("DXB")
    
    assert_not_nil airport
    assert_equal "DXB", airport.iata_code
    assert_equal "OMDB", airport.icao_code
  end

  test "should find airport by ICAO code" do
    AirportDataService.seed_airports
    
    airport = AirportDataService.find_by_code("OMDB")
    
    assert_not_nil airport
    assert_equal "DXB", airport.iata_code
    assert_equal "OMDB", airport.icao_code
  end

  test "should return nil for invalid airport code" do
    AirportDataService.seed_airports
    
    airport = AirportDataService.find_by_code("XXX")
    
    assert_nil airport
  end

  test "should return nil for blank airport code" do
    airport = AirportDataService.find_by_code("")
    
    assert_nil airport
  end

  test "should return nil for invalid length airport code" do
    airport = AirportDataService.find_by_code("INVALID")
    
    assert_nil airport
  end

  test "should check operational status for active airport" do
    AirportDataService.seed_airports
    
    status = AirportDataService.operational_status_check("DXB")
    
    assert_equal "operational", status[:status]
    assert_equal "Airport is operational", status[:message]
  end

  test "should check operational status for inactive airport" do
    AirportDataService.seed_airports
    # Change an airport to inactive for testing
    airport = Airport.find_by(iata_code: "DXB")
    airport.update!(operational_status: :inactive)
    
    status = AirportDataService.operational_status_check("DXB")
    
    assert_equal "closed", status[:status]
    assert_equal "Airport is currently closed", status[:message]
  end

  test "should check operational status for restricted airport" do
    AirportDataService.seed_airports
    # Change an airport to restricted for testing
    airport = Airport.find_by(iata_code: "DXB")
    airport.update!(operational_status: :restricted)
    
    status = AirportDataService.operational_status_check("DXB")
    
    assert_equal "restricted", status[:status]
    assert_equal "Airport has operational restrictions", status[:message]
  end

  test "should return unknown status for non-existent airport" do
    status = AirportDataService.operational_status_check("XXX")
    
    assert_equal "unknown", status[:status]
    assert_equal "Airport not found", status[:message]
  end

  test "should handle case insensitive airport codes" do
    AirportDataService.seed_airports
    
    airport_upper = AirportDataService.find_by_code("DXB")
    airport_lower = AirportDataService.find_by_code("dxb")
    
    assert_not_nil airport_upper
    assert_not_nil airport_lower
    assert_equal airport_upper.id, airport_lower.id
  end

  test "should handle whitespace in airport codes" do
    AirportDataService.seed_airports
    
    airport = AirportDataService.find_by_code("  DXB  ")
    
    assert_not_nil airport
    assert_equal "DXB", airport.iata_code
  end
end
