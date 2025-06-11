class Api::V1::FlightRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_flight_request, only: [ :show, :update, :destroy ]
  before_action :authorize_request_access, only: [ :show, :update, :destroy ]

  # GET /api/v1/flight_requests
  def index
    @flight_requests = filtered_flight_requests
                      .includes(:vip_profile, :source_of_request_user, :flight_request_legs)
                      .limit(params[:per_page] || 10)
                      .offset(params[:page].to_i * (params[:per_page] || 10).to_i)
                      .order(created_at: :desc)

    render json: {
      flight_requests: @flight_requests.map { |fr| flight_request_summary(fr) },
      pagination: {
        current_page: params[:page] || 1,
        per_page: params[:per_page] || 10,
        total_count: filtered_flight_requests.count
      }
    }
  end

  # GET /api/v1/flight_requests/:id
  def show
    render json: flight_request_details(@flight_request)
  end

  # POST /api/v1/flight_requests
  def create
    @flight_request = FlightRequest.new(flight_request_params)
    @flight_request.source_of_request_user = current_user
    @flight_request.vip_profile_id = params[:vip_profile_id]
    @flight_request.status = :sent

    if @flight_request.save
      log_action("flight_request_created", @flight_request)
      render json: {
        message: "Flight request created successfully",
        flight_request: flight_request_details(@flight_request),
        confirmation_required: true
      }, status: :created
    else
      render json: {
        errors: @flight_request.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/flight_requests/:id
  def update
    if @flight_request.update(flight_request_params)
      log_action("flight_request_updated", @flight_request)
      render json: {
        message: "Flight request updated successfully",
        flight_request: flight_request_details(@flight_request)
      }
    else
      render json: {
        errors: @flight_request.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/flight_requests/:id (Soft delete only)
  def destroy
    unless current_user.admin?
      render json: { error: "Unauthorized" }, status: :forbidden
      return
    end

    @flight_request.soft_delete
    log_action("flight_request_deleted", @flight_request)

    render json: {
      message: "Flight request deleted successfully"
    }
  end

  # PUT /api/v1/flight_requests/:id/status
  def update_status
    @flight_request = FlightRequest.find(params[:id])

    unless can_update_status?
      render json: { error: "Unauthorized to update status" }, status: :forbidden
      return
    end

    old_status = @flight_request.status

    if @flight_request.update(status: params[:status])
      log_action("flight_request_status_updated", @flight_request, {
        old_status: old_status,
        new_status: @flight_request.status
      })

      render json: {
        message: "Status updated successfully",
        flight_request: flight_request_details(@flight_request)
      }
    else
      render json: {
        errors: @flight_request.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/flight_requests/:id/passenger_list
  def upload_passenger_list
    @flight_request = FlightRequest.find(params[:id])

    unless @flight_request.status == "done"
      render json: { error: "Can only upload passenger list for completed requests" }, status: :unprocessable_entity
      return
    end

    if params[:passenger_list_file].present?
      # File upload logic would go here
      render json: { message: "Passenger list uploaded successfully" }
    else
      render json: { error: "No file provided" }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/flight_requests/:id/flight_brief
  def upload_flight_brief
    @flight_request = FlightRequest.find(params[:id])

    unless current_user.operations_staff? || current_user.admin?
      render json: { error: "Unauthorized" }, status: :forbidden
      return
    end

    if params[:flight_brief_file].present?
      # File upload logic would go here
      render json: { message: "Flight brief uploaded successfully" }
    else
      render json: { error: "No file provided" }, status: :unprocessable_entity
    end
  end

  private

  def set_flight_request
    @flight_request = FlightRequest.find(params[:id])
  end

  def flight_request_params
    params.require(:flight_request).permit(
      :flight_date, :departure_time, :arrival_time,
      :departure_airport_code, :arrival_airport_code,
      :number_of_passengers, :reason_unable_to_process
    )
  end

  def filtered_flight_requests
    requests = FlightRequest.not_deleted

    case current_user.role
    when "source_of_request"
      # Source users see only their own requests
      requests = requests.by_requester(current_user)
    when "vip"
      # VIPs see only requests for their profile
      requests = requests.for_vip(current_user.vip_profile)
    when "operations_staff", "operations_admin", "management", "super_admin"
      # Operations and admin users see all requests
      requests = requests.all
    end

    # Apply additional filters
    requests = requests.where(status: params[:status]) if params[:status].present?
    requests = requests.where(vip_profile_id: params[:vip_profile_id]) if params[:vip_profile_id].present?
    requests = requests.where("flight_date >= ?", params[:from_date]) if params[:from_date].present?
    requests = requests.where("flight_date <= ?", params[:to_date]) if params[:to_date].present?

    requests
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

  def can_update_status?
    current_user.operations_staff? || current_user.admin?
  end

  def flight_request_summary(flight_request)
    {
      id: flight_request.id,
      request_number: flight_request.request_number,
      flight_date: flight_request.flight_date,
      departure_airport: flight_request.departure_airport_code,
      arrival_airport: flight_request.arrival_airport_code,
      departure_time: flight_request.departure_time,
      arrival_time: flight_request.arrival_time,
      passengers: flight_request.number_of_passengers,
      status: flight_request.status,
      vip_profile: flight_request.vip_profile.internal_codename,
      created_at: flight_request.created_at,
      overdue_alerts: flight_request.overdue_alerts
    }
  end

  def flight_request_details(flight_request)
    {
      id: flight_request.id,
      request_number: flight_request.request_number,
      flight_date: flight_request.flight_date,
      departure_airport: flight_request.departure_airport_code,
      arrival_airport: flight_request.arrival_airport_code,
      departure_time: flight_request.departure_time,
      arrival_time: flight_request.arrival_time,
      passengers: flight_request.number_of_passengers,
      status: flight_request.status,
      reason_unable_to_process: flight_request.unable_reason,
      vip_profile: {
        id: flight_request.vip_profile.id,
        codename: flight_request.vip_profile.internal_codename
      },
      source_of_request_user: {
        id: flight_request.source_of_request_user.id,
        name: flight_request.source_of_request_user.name
      },
      legs: flight_request.flight_request_legs.map do |leg|
        {
          id: leg.id,
          leg_number: leg.leg_number,
          departure_airport: leg.departure_airport_code,
          arrival_airport: leg.arrival_airport_code,
          departure_time: leg.departure_time,
          arrival_time: leg.arrival_time
        }
      end,
      created_at: flight_request.created_at,
      updated_at: flight_request.updated_at,
      overdue_alerts: flight_request.overdue_alerts
    }
  end



  def log_action(action, resource, additional_data = {})
    # Map action strings to enum values
    action_type_map = {
      "flight_request_created" => :create,
      "flight_request_updated" => :update,
      "flight_request_deleted" => :delete,
      "flight_request_status_updated" => :status_change
    }

    AuditLog.create!(
      user: current_user,
      action_type: action_type_map[action] || :update,
      resource_type: resource.class.name,
      resource_id: resource.id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      metadata: additional_data
    )
  end

  # Placeholder for authentication - you'll need to implement this based on your auth system
  def authenticate_user!
    true if Rails.env.test?
    # Implementation depends on your authentication strategy
  end

  def current_user
    return @test_current_user if Rails.env.test? && @test_current_user
    # Implementation depends on your authentication strategy
    @current_user
  end
end
