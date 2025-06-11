require "test_helper"

class Api::V1::VipProfilesControllerBasicTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin)
    @operations_staff = users(:operations_staff)
    @source_user = users(:source_user)
    
    # Create a test VIP profile without encryption for now
    @vip_profile = VipProfile.create!(
      internal_codename: "VIPTEST001",
      actual_name: "Test VIP Person",
      security_clearance_level: "SECRET",
      status: "active",
      created_by_user: @admin
    )
  end

  def teardown
    @vip_profile&.destroy
  end

  # Basic CRUD tests
  test "should create vip profile" do
    profile_params = {
      vip_profile: {
        actual_name: "New Test VIP",
        security_clearance_level: "TOP_SECRET"
      }
    }

    assert_difference("VipProfile.count") do
      post api_v1_vip_profiles_url, 
           params: profile_params, 
           headers: auth_headers(@admin)
    end

    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal "New Test VIP", response_data["actual_name"]
    assert response_data["internal_codename"].present?
  end

  test "should get vip profiles index" do
    get api_v1_vip_profiles_url, headers: auth_headers(@admin)
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data.is_a?(Array)
  end

  test "should show vip profile" do
    get api_v1_vip_profile_url(@vip_profile), headers: auth_headers(@admin)
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal @vip_profile.id, response_data["id"]
  end

  test "should update vip profile" do
    update_params = {
      vip_profile: {
        actual_name: "Updated VIP Name"
      }
    }

    put api_v1_vip_profile_url(@vip_profile), 
        params: update_params, 
        headers: auth_headers(@admin)

    assert_response :success
    @vip_profile.reload
    assert_equal "Updated VIP Name", @vip_profile.actual_name
  end

  test "should soft delete vip profile" do
    delete api_v1_vip_profile_url(@vip_profile), headers: auth_headers(@admin)
    
    assert_response :no_content
    @vip_profile.reload
    assert @vip_profile.deleted?
  end

  test "should handle preference data" do
    profile_params = {
      vip_profile: {
        actual_name: "Test VIP with Preferences",
        security_clearance_level: "SECRET",
        personal_preferences: { "dietary_restrictions" => "None" },
        standard_destinations: { "frequent" => ["DXB", "AUH"] },
        preferred_aircraft_types: { "primary" => "G650" }
      }
    }

    assert_difference("VipProfile.count") do
      post api_v1_vip_profiles_url, 
           params: profile_params, 
           headers: auth_headers(@admin)
    end

    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal "Test VIP with Preferences", response_data["actual_name"]
  end

  private

  def auth_headers(user)
    # Simple mock authentication for testing
    { "X-User-ID" => user.id.to_s }
  end
end
