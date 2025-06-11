require "test_helper"

class Api::V1::OperationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @operations_user = User.create!(
      email: "ops@example.com",
      role: "operations_staff",
      status: "active",
      first_name: "Operations",
      last_name: "Staff"
    )
    
    @admin_user = User.create!(
      email: "admin@example.com",
      role: "super_admin", 
      status: "active",
      first_name: "Admin",
      last_name: "User"
    )
    
    @vip_profile = VipProfile.create!(
      internal_codename: "TESTVIP",
      actual_name: "Test VIP",
      security_clearance_level: 3,
      status: "active",
      created_by_user: @admin_user
    )
    
    @source_user = User.create!(
      uae_pass_id: "UAE123456",
      role: "source_of_request",
      status: "active",
      first_name: "Source",
      last_name: "User"
    )
    
    @flight_request = FlightRequest.create!(
      vip_profile: @vip_profile,
      source_of_request_user: @source_user,
      flight_date: Date.tomorrow,
      number_of_passengers: 3,
      status: "sent"
    )
  end

  test "should require authentication" do
    put "/api/v1/operations/requests/#{@flight_request.id}/receive"
    assert_response :unauthorized
  end

  test "should require operations staff role" do
    sign_in @source_user
    put "/api/v1/operations/requests/#{@flight_request.id}/receive"
    assert_response :forbidden
  end

  test "should mark request as received" do
    sign_in @operations_user
    put "/api/v1/operations/requests/#{@flight_request.id}/receive"
    
    assert_response :success
    @flight_request.reload
    assert_equal 'received', @flight_request.status
    assert_not_nil @flight_request.received_at
  end

  test "should mark request under review" do
    sign_in @operations_user
    @flight_request.update!(status: 'received')
    
    put "/api/v1/operations/requests/#{@flight_request.id}/review"
    
    assert_response :success
    @flight_request.reload
    assert_equal 'under_review', @flight_request.status
    assert_not_nil @flight_request.reviewed_at
  end

  test "should mark request under process" do
    sign_in @operations_user
    @flight_request.update!(status: 'under_review')
    
    put "/api/v1/operations/requests/#{@flight_request.id}/process"
    
    assert_response :success
    @flight_request.reload
    assert_equal 'under_process', @flight_request.status
    assert_not_nil @flight_request.processed_at
  end

  test "should mark request as unable with reason" do
    sign_in @operations_user
    @flight_request.update!(status: 'under_process')
    
    put "/api/v1/operations/requests/#{@flight_request.id}/unable", params: { reason: "Aircraft unavailable" }
    
    assert_response :success
    @flight_request.reload
    assert_equal 'unable', @flight_request.status
    assert_equal "Aircraft unavailable", @flight_request.unable_reason
    assert_not_nil @flight_request.unable_at
  end

  test "should require reason for unable status" do
    sign_in @operations_user
    @flight_request.update!(status: 'under_process')
    
    put "/api/v1/operations/requests/#{@flight_request.id}/unable"
    
    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_includes response_data['errors'], 'Reason is required'
  end

  test "should mark request as complete" do
    sign_in @operations_user
    @flight_request.update!(status: 'under_process')
    
    put "/api/v1/operations/requests/#{@flight_request.id}/complete"
    
    assert_response :success
    @flight_request.reload
    assert_equal 'completed', @flight_request.status
    assert_not_nil @flight_request.completed_at
  end

  test "should modify request details" do
    sign_in @operations_user
    original_date = @flight_request.flight_date
    new_date = Date.tomorrow + 1.day
    
    put "/api/v1/operations/requests/#{@flight_request.id}/modify", params: {
      flight_request: {
        flight_date: new_date,
        number_of_passengers: 5
      }
    }
    
    assert_response :success
    @flight_request.reload
    assert_equal new_date, @flight_request.flight_date
    assert_equal 5, @flight_request.number_of_passengers
    
    # Check audit log was created
    audit_log = AuditLog.where(auditable: @flight_request, action: 'modification').last
    assert_not_nil audit_log
    assert_equal @operations_user, audit_log.user
  end

  test "should get alerts for requests approaching deadlines" do
    sign_in @operations_user
    
    # Create request with flight tomorrow (should trigger alerts)
    tomorrow_request = FlightRequest.create!(
      vip_profile: @vip_profile,
      source_of_request_user: @source_user,
      flight_date: Date.tomorrow,
      number_of_passengers: 2,
      status: 'under_review'
    )
    
    get "/api/v1/operations/alerts"
    
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_includes response_data.keys, 'alerts'
    assert response_data['alerts'].is_a?(Array)
    
    # Should include our tomorrow request
    alert_ids = response_data['alerts'].map { |alert| alert['id'] }
    assert_includes alert_ids, tomorrow_request.id
  end

  test "should get completed flights with filters" do
    sign_in @operations_user
    
    # Create completed request
    completed_request = FlightRequest.create!(
      vip_profile: @vip_profile,
      source_of_request_user: @source_user,
      flight_date: Date.yesterday,
      number_of_passengers: 3,
      status: 'completed',
      completed_at: 1.hour.ago
    )
    
    get "/api/v1/operations/completed_flights"
    
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_includes response_data.keys, 'completed_flights'
    assert response_data['completed_flights'].is_a?(Array)
  end

  test "should get canceled flights" do
    sign_in @operations_user
    
    # Create unable request
    unable_request = FlightRequest.create!(
      vip_profile: @vip_profile,
      source_of_request_user: @source_user,
      flight_date: Date.yesterday,
      number_of_passengers: 2,
      status: 'unable',
      unable_reason: "Weather conditions",
      unable_at: 2.hours.ago
    )
    
    get "/api/v1/operations/canceled_flights"
    
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_includes response_data.keys, 'canceled_flights'
    assert response_data['canceled_flights'].is_a?(Array)
  end

  test "should return not found for non-existent request" do
    sign_in @operations_user
    
    put "/api/v1/operations/requests/99999/receive"
    
    assert_response :not_found
    response_data = JSON.parse(response.body)
    assert_equal 'Flight request not found', response_data['error']
  end

  test "should create audit logs for status changes" do
    sign_in @operations_user
    initial_audit_count = AuditLog.count
    
    put "/api/v1/operations/requests/#{@flight_request.id}/receive"
    
    assert_response :success
    assert_equal initial_audit_count + 1, AuditLog.count
    
    audit_log = AuditLog.last
    assert_equal @flight_request, audit_log.auditable
    assert_equal @operations_user, audit_log.user
    assert_equal 'status_change', audit_log.action
  end

  private

  def sign_in(user)
    # Mock authentication - adjust based on your authentication system
    request.headers['Authorization'] = "Bearer mock_token_for_#{user.id}"
  end
end
