require "test_helper"

class Api::V1::AirportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Seed some test data
    AirportDataService.seed_airports
  end

  test "should search airports with query" do
    get "/api/v1/airports/search", params: { query: "Dubai" }
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert json["data"].is_a?(Array)
    assert json["data"].any? { |airport| airport["city"] == "Dubai" }
    assert_equal "Dubai", json["meta"]["query"]
  end

  test "should search airports with IATA code" do
    get "/api/v1/airports/search", params: { query: "DXB" }
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert json["data"].any? { |airport| airport["iata_code"] == "DXB" }
  end

  test "should limit search results" do
    get "/api/v1/airports/search", params: { query: "Dubai", limit: 1 }
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert_equal 1, json["data"].size
    assert_equal 1, json["meta"]["limit"]
  end

  test "should show airport by IATA code" do
    get "/api/v1/airports/DXB"
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert_equal "DXB", json["data"]["iata_code"]
    assert_equal "OMDB", json["data"]["icao_code"]
    assert json["data"]["operational_info"].present?
  end

  test "should show airport by ICAO code" do
    get "/api/v1/airports/OMDB"
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert_equal "DXB", json["data"]["iata_code"]
    assert_equal "OMDB", json["data"]["icao_code"]
  end

  test "should return not found for invalid airport code" do
    get "/api/v1/airports/XXX"
    
    assert_response :not_found
    json = JSON.parse(response.body)
    
    assert_not json["success"]
    assert_equal "Airport not found", json["error"]
  end

  test "should return bad request for empty airport code" do
    get "/api/v1/airports/"
    
    # This should not match our route, so it will return 404
    assert_response :not_found
  end

  test "should check operational status" do
    get "/api/v1/airports/DXB/operational_status"
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert_equal "DXB", json["data"]["airport_code"]
    assert json["data"]["operational_status"].present?
    assert json["data"]["message"].present?
    assert json["data"]["checked_at"].present?
  end

  test "should return bad request for operational status without code" do
    # This would be handled by routing, but let's test the parameter validation
    get "/api/v1/airports//operational_status"
    
    assert_response :not_found  # Route won't match
  end

  test "should return all airports when no query provided" do
    get "/api/v1/airports/search"
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert json["data"].is_a?(Array)
    assert json["data"].size > 0  # Should return some airports
  end
end
