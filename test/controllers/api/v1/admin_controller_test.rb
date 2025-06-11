require "test_helper"

class Api::V1::AdminControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = User.create!(
      email: "admin@example.com",
      role: "super_admin",
      status: "active",
      first_name: "Admin",
      last_name: "User"
    )
    
    @operations_user = User.create!(
      email: "ops@example.com",
      role: "operations_staff",
      status: "active",
      first_name: "Operations",
      last_name: "Staff"
    )
    
    @source_user = User.create!(
      uae_pass_id: "UAE123456",
      role: "source_of_request",
      status: "active",
      first_name: "Source",
      last_name: "User"
    )
    
    @vip_profile = VipProfile.create!(
      internal_codename: "TESTVIP",
      actual_name: "Test VIP",
      security_clearance_level: 3,
      status: "active",
      created_by_user: @admin_user
    )
    
    @flight_request = FlightRequest.create!(
      vip_profile: @vip_profile,
      source_of_request_user: @source_user,
      flight_date: Date.tomorrow,
      number_of_passengers: 2,
      status: "sent"
    )
  end

  test "should require authentication" do
    post "/api/v1/admin/users"
    assert_response :unauthorized
  end

  test "should require admin role" do
    sign_in @operations_user
    post "/api/v1/admin/users"
    assert_response :forbidden
  end

  test "should create new user" do
    sign_in @admin_user
    
    assert_difference('User.count') do
      post "/api/v1/admin/users", params: {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          role: "operations_staff",
          first_name: "New",
          last_name: "User",
          phone_number: "+1234567890"
        }
      }
    end
    
    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal "User created successfully", response_data['message']
    assert_includes response_data.keys, 'user'
    assert_equal "newuser@example.com", response_data['user']['email']
  end

  test "should list all users with pagination" do
    sign_in @admin_user
    
    get "/api/v1/admin/users"
    
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_includes response_data.keys, 'users'
    assert_includes response_data.keys, 'pagination'
    assert response_data['users'].is_a?(Array)
  end

  test "should filter users by role" do
    sign_in @admin_user
    
    get "/api/v1/admin/users", params: { role: "operations_staff" }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    # All returned users should have operations_staff role
    response_data['users'].each do |user|
      assert_equal "operations_staff", user['role']
    end
  end

  test "should update user" do
    sign_in @admin_user
    
    put "/api/v1/admin/users/#{@source_user.id}", params: {
      user: {
        first_name: "Updated",
        last_name: "Name",
        role: "vip"
      }
    }
    
    assert_response :success
    @source_user.reload
    assert_equal "Updated", @source_user.first_name
    assert_equal "Name", @source_user.last_name
    assert_equal "vip", @source_user.role
  end

  test "should soft delete user" do
    sign_in @admin_user
    
    delete "/api/v1/admin/users/#{@source_user.id}"
    
    assert_response :success
    @source_user.reload
    assert_equal "frozen", @source_user.status
    assert_not_nil @source_user.deleted_at
  end

  test "should create VIP profile" do
    sign_in @admin_user
    
    assert_difference('VipProfile.count') do
      post "/api/v1/admin/vip_profiles", params: {
        vip_profile: {
          name: "Test VIP",
          security_clearance: "high",
          preferred_aircraft_type: "Boeing 737",
          special_requirements: "Special dietary needs"
        }
      }
    end
    
    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal "VIP Profile created successfully", response_data['message']
    
    # Should have auto-generated codename
    assert_not_nil response_data['vip_profile']['codename']
  end

  test "should list VIP profiles" do
    sign_in @admin_user
    
    get "/api/v1/admin/vip_profiles"
    
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_includes response_data.keys, 'vip_profiles'
    assert_includes response_data.keys, 'pagination'
    assert response_data['vip_profiles'].is_a?(Array)
  end

  test "should show VIP name to admin users" do
    sign_in @admin_user
    
    get "/api/v1/admin/vip_profiles"
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    # Admin should see actual VIP names
    vip_data = response_data['vip_profiles'].first
    assert_includes vip_data.keys, 'name'
  end

  test "should update VIP profile" do
    sign_in @admin_user
    
    put "/api/v1/admin/vip_profiles/#{@vip_profile.id}", params: {
      vip_profile: {
        preferred_aircraft_type: "Airbus A320",
        security_clearance: "top_secret"
      }
    }
    
    assert_response :success
    @vip_profile.reload
    assert_equal "Airbus A320", @vip_profile.preferred_aircraft_type
    assert_equal "top_secret", @vip_profile.security_clearance
  end

  test "should soft delete VIP profile" do
    sign_in @admin_user
    
    delete "/api/v1/admin/vip_profiles/#{@vip_profile.id}"
    
    assert_response :success
    @vip_profile.reload
    assert_not_nil @vip_profile.deleted_at
  end

  test "should admin delete flight request" do
    sign_in @admin_user
    
    delete "/api/v1/admin/flight_requests/#{@flight_request.id}"
    
    assert_response :success
    @flight_request.reload
    assert_equal "deleted", @flight_request.status
    assert_not_nil @flight_request.deleted_at
  end

  test "should finalize flight request" do
    sign_in @admin_user
    @flight_request.update!(status: 'under_process')
    
    put "/api/v1/admin/flight_requests/#{@flight_request.id}/finalize"
    
    assert_response :success
    @flight_request.reload
    assert_equal "completed", @flight_request.status
    assert_equal @admin_user.id, @flight_request.finalized_by
    assert_not_nil @flight_request.completed_at
  end

  test "should return not found for non-existent user" do
    sign_in @admin_user
    
    put "/api/v1/admin/users/99999", params: { user: { first_name: "Test" } }
    
    assert_response :not_found
    response_data = JSON.parse(response.body)
    assert_equal 'User not found', response_data['error']
  end

  test "should return not found for non-existent VIP profile" do
    sign_in @admin_user
    
    put "/api/v1/admin/vip_profiles/99999", params: { vip_profile: { name: "Test" } }
    
    assert_response :not_found
    response_data = JSON.parse(response.body)
    assert_equal 'VIP Profile not found', response_data['error']
  end

  test "should return not found for non-existent flight request" do
    sign_in @admin_user
    
    delete "/api/v1/admin/flight_requests/99999"
    
    assert_response :not_found
    response_data = JSON.parse(response.body)
    assert_equal 'Flight request not found', response_data['error']
  end

  test "should create audit logs for admin actions" do
    sign_in @admin_user
    initial_audit_count = AuditLog.count
    
    post "/api/v1/admin/users", params: {
      user: {
        email: "audittest@example.com",
        password: "password123",
        password_confirmation: "password123",
        role: "operations_staff",
        first_name: "Audit",
        last_name: "Test"
      }
    }
    
    assert_response :created
    assert_equal initial_audit_count + 1, AuditLog.count
    
    audit_log = AuditLog.last
    assert_equal @admin_user, audit_log.user
    assert_equal 'user_created', audit_log.action
  end

  test "should validate user creation parameters" do
    sign_in @admin_user
    
    post "/api/v1/admin/users", params: {
      user: {
        email: "", # Invalid email
        password: "123", # Too short
        role: "operations_staff"
      }
    }
    
    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_includes response_data.keys, 'errors'
  end

  test "should validate VIP profile creation parameters" do
    sign_in @admin_user
    
    post "/api/v1/admin/vip_profiles", params: {
      vip_profile: {
        name: "", # Invalid name
        security_clearance: "invalid_clearance"
      }
    }
    
    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_includes response_data.keys, 'errors'
  end

  test "operations admin should have access" do
    operations_admin = User.create!(
      email: "ops_admin@example.com", 
      role: "operations_admin",
      status: "active",
      first_name: "Ops",
      last_name: "Admin"
    )
    
    sign_in operations_admin
    
    get "/api/v1/admin/users"
    assert_response :success
  end

  test "management should have access" do
    management_user = User.create!(
      email: "management@example.com", 
      role: "management",
      status: "active",
      first_name: "Manager",
      last_name: "User"
    )
    
    sign_in management_user
    
    get "/api/v1/admin/users"
    assert_response :success
  end

  private

  def sign_in(user)
    # Mock authentication - adjust based on your authentication system
    request.headers['Authorization'] = "Bearer mock_token_for_#{user.id}"
  end
end
