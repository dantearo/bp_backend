class Api::V1::FlightRequestLegsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_flight_request
  before_action :set_flight_request_leg, only: [ :show, :update, :destroy ]
  before_action :authorize_request_access

  # POST /api/v1/flight_requests/:flight_request_id/legs
  def create
    @leg = @flight_request.flight_request_legs.build(leg_params)
    @leg.leg_number = next_leg_number

    if @leg.save
      log_action("flight_request_leg_created", @leg)
      render json: {
        message: "Flight leg added successfully",
        leg: leg_details(@leg)
      }, status: :created
    else
      render json: {
        errors: @leg.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/flight_requests/:flight_request_id/legs/:id
  def update
    if @leg.update(leg_params)
      log_action("flight_request_leg_updated", @leg)
      render json: {
        message: "Flight leg updated successfully",
        leg: leg_details(@leg)
      }
    else
      render json: {
        errors: @leg.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/flight_requests/:flight_request_id/legs/:id
  def destroy
    @leg.destroy
    log_action("flight_request_leg_deleted", @leg)

    # Reorder remaining legs to maintain sequence
    reorder_legs

    render json: {
      message: "Flight leg removed successfully"
    }
  end

  private

  def set_flight_request
    @flight_request = FlightRequest.find(params[:flight_request_id])
  end

  def set_flight_request_leg
    @leg = @flight_request.flight_request_legs.find(params[:id])
  end

  def leg_params
    params.require(:leg).permit(
      :departure_airport_code, :arrival_airport_code,
      :departure_time, :arrival_time
    )
  end

  def authorize_request_access
    case current_user.role
    when "source_of_request"
      unless @flight_request.source_of_request_user == current_user
        render json: { error: "Unauthorized" }, status: :forbidden
        nil
      end
    when "vip"
      unless @flight_request.vip_profile == current_user.vip_profile
        render json: { error: "Unauthorized" }, status: :forbidden
        nil
      end
    when "operations_staff", "operations_admin", "management", "super_admin"
      # Operations and admin users can access all requests
    else
      render json: { error: "Unauthorized" }, status: :forbidden
      nil
    end
  end

  def next_leg_number
    last_leg = @flight_request.flight_request_legs.order(:leg_number).last
    last_leg ? last_leg.leg_number + 1 : 1
  end

  def reorder_legs
    @flight_request.flight_request_legs.order(:leg_number).each_with_index do |leg, index|
      leg.update_column(:leg_number, index + 1)
    end
  end

  def leg_details(leg)
    {
      id: leg.id,
      leg_number: leg.leg_number,
      departure_airport: leg.departure_airport_code,
      arrival_airport: leg.arrival_airport_code,
      departure_time: leg.departure_time,
      arrival_time: leg.arrival_time,
      created_at: leg.created_at,
      updated_at: leg.updated_at
    }
  end

  def log_action(action, resource, additional_data = {})
    AuditLog.create!(
      user: current_user,
      action: action,
      resource_type: resource.class.name,
      resource_id: resource.id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      additional_data: additional_data.merge(flight_request_id: @flight_request.id)
    )
  end

  # Placeholder for authentication - you'll need to implement this based on your auth system
  def authenticate_user!
    # Implementation depends on your authentication strategy
  end

  def current_user
    # Implementation depends on your authentication strategy
    @current_user
  end
end
