require "test_helper"

class Api::V1::FlightRequestsControllerTest < ActionController::TestCase
  setup do
    @vip_profile = vip_profiles(:one)
    @source_user = users(:source_user)
    @operations_user = users(:operations_staff)
    @flight_request = flight_requests(:one)
  end

  test "should get index for operations staff" do
    sign_in(@operations_user)
    get :index
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.has_key?("flight_requests")
    assert json_response.has_key?("pagination")
  end

  test "should show flight request" do
    sign_in(@operations_user)
    get :show, params: { id: @flight_request.id }
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @flight_request.id, json_response["id"]
    assert_equal @flight_request.request_number, json_response["request_number"]
  end

  test "should create flight request" do
    sign_in(@source_user)

    assert_difference("FlightRequest.count") do
      post :create, params: {
        vip_profile_id: @vip_profile.id,
        flight_request: {
          flight_date: Date.tomorrow,
          departure_airport_code: "JFK",
          arrival_airport_code: "LAX",
          departure_time: "14:30",
          number_of_passengers: 2
        }
      }
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response.has_key?("confirmation_required")
    assert_equal "sent", json_response["flight_request"]["status"]
  end

  test "should not create flight request without required fields" do
    sign_in(@source_user)

    assert_no_difference("FlightRequest.count") do
      post :create, params: {
        vip_profile_id: @vip_profile.id,
        flight_request: {
          flight_date: Date.tomorrow
          # Missing required fields
        }
      }
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response.has_key?("errors")
  end

  test "should update flight request" do
    sign_in(@operations_user)

    patch :update, params: {
      id: @flight_request.id,
      flight_request: {
        number_of_passengers: 5
      }
    }

    assert_response :success
    @flight_request.reload
    assert_equal 5, @flight_request.number_of_passengers
  end

  test "should update flight request status" do
    sign_in(@operations_user)

    put :update_status, params: {
      id: @flight_request.id,
      status: "received"
    }

    assert_response :success
    @flight_request.reload
    assert_equal "received", @flight_request.status
  end

  test "should not allow source user to update status" do
    sign_in(@source_user)

    put :update_status, params: {
      id: @flight_request.id,
      status: "received"
    }

    assert_response :forbidden
  end

  test "should soft delete flight request for admin only" do
    admin_user = users(:admin)
    sign_in(admin_user)

    delete :destroy, params: { id: @flight_request.id }
    assert_response :success

    @flight_request.reload
    assert_not_nil @flight_request.deleted_at
  end

  test "should not allow non-admin to delete" do
    sign_in(@source_user)

    delete :destroy, params: { id: @flight_request.id }
    assert_response :forbidden
  end

  test "should filter requests by user role" do
    sign_in(@source_user)
    get :index

    assert_response :success
    json_response = JSON.parse(response.body)

    # Source users should only see their own requests
    json_response["flight_requests"].each do |request|
      assert_equal @source_user.id, request["source_of_request_user"]["id"] if request["source_of_request_user"]
    end
  end

  private

  def sign_in(user)
    # Set the test user for authentication
    @controller.instance_variable_set(:@test_current_user, user)
  end
end
