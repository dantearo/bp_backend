require "test_helper"

class Api::V1::AuditControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = User.create!(
      email: "audit_admin_#{SecureRandom.hex(4)}@presidentialflight.ae",
      first_name: "Admin",
      last_name: "User",
      role: "operations_admin",
      status: "active"
    )
    @regular_user = User.create!(
      uae_pass_id: "UAE#{SecureRandom.hex(6)}",
      first_name: "Regular",
      last_name: "User",
      role: "source_of_request",
      status: "active"
    )
    @flight_request = FlightRequest.create!(
      request_number: "001/2024",
      departure_airport_code: "DXB",
      arrival_airport_code: "AUH",
      flight_date: Date.tomorrow,
      departure_time: "10:00",
      number_of_passengers: 3,
      status: "sent",
      source_of_request_user: @regular_user,
      vip_profile: VipProfile.create!(
        internal_codename: "ALPHA",
        actual_name: "VIP One",
        security_clearance_level: "high",
        personal_preferences: {},
        status: "active",
        created_by_user: @admin_user
      )
    )
    
    # Create some audit logs
    @audit_log = AuditLog.create!(
      user: @regular_user,
      action_type: "create",
      resource_type: "FlightRequest",
      resource_id: @flight_request.id,
      ip_address: "192.168.1.1",
      user_agent: "Test Browser",
      metadata: { test: "data" }
    )
  end

  test "should require admin permissions for logs endpoint" do
    get "/api/v1/audit/logs"
    assert_response :forbidden
  end

  test "should allow admin to view audit logs" do
    sign_in(@admin_user)
    get "/api/v1/audit/logs"
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data.has_key?("audit_logs")
    assert response_data.has_key?("pagination")
  end

  test "should filter audit logs by user" do
    sign_in(@admin_user)
    get "/api/v1/audit/logs", params: { user_id: @regular_user.id }
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data["audit_logs"].length
    assert_equal @regular_user.id, response_data["audit_logs"].first["user"]["id"]
  end

  test "should show individual audit log" do
    sign_in(@admin_user)
    get "/api/v1/audit/logs/#{@audit_log.id}"
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal @audit_log.id, response_data["audit_log"]["id"]
    assert response_data["audit_log"].has_key?("metadata")
  end

  test "should allow users to view their own activity" do
    get "/api/v1/audit/user_activity/#{@regular_user.id}", 
        headers: { "Authorization" => "Bearer mock_token_for_#{@regular_user.id}" }
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal @regular_user.id, response_data["user"]["id"]
    assert response_data.has_key?("activity_summary")
    assert response_data.has_key?("audit_logs")
  end

  test "should prevent users from viewing other users' activity" do
    other_user = User.create!(
      uae_pass_id: "UAE#{SecureRandom.hex(6)}",
      first_name: "Other",
      last_name: "User",
      role: "source_of_request",
      status: "active"
    )
    
    get "/api/v1/audit/user_activity/#{@regular_user.id}", 
        headers: { "Authorization" => "Bearer mock_token_for_#{other_user.id}" }
    assert_response :forbidden
  end

  test "should show request history" do
    sign_in(@admin_user)
    get "/api/v1/audit/request_history/#{@flight_request.id}"
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal @flight_request.id, response_data["flight_request"]["id"]
    assert response_data.has_key?("history")
    assert response_data.has_key?("timeline")
  end

  test "should provide security events summary" do
    sign_in(@admin_user)
    get "/api/v1/audit/security_events"
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data.has_key?("security_summary")
    assert response_data.has_key?("recommendations")
  end

  private

  def sign_in(user)
    request.headers["Authorization"] = "Bearer mock_token_for_#{user.id}"
  end
end
