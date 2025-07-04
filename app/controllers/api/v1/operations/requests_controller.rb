class Api::V1::Operations::RequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_operations_staff!
  before_action :set_flight_request, only: [:receive, :review, :start_process, :unable, :complete, :modify]

  # PUT /api/v1/operations/requests/:id/receive - Mark as received
  def receive
    if @flight_request.update(status: 'received', received_at: Time.current)
      AuditLog.create(
        auditable: @flight_request,
        user: current_user,
        action: 'status_change',
        changes: { status: ['sent', 'received'] },
        metadata: { timestamp: Time.current }
      )
      render json: { message: 'Request marked as received', flight_request: @flight_request }, status: :ok
    else
      render json: { errors: @flight_request.errors }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/operations/requests/:id/review - Start review process
  def review
    if @flight_request.update(status: 'under_review', reviewed_at: Time.current)
      AuditLog.create(
        auditable: @flight_request,
        user: current_user,
        action: 'status_change',
        changes: { status: ['received', 'under_review'] },
        metadata: { timestamp: Time.current }
      )
      render json: { message: 'Request under review', flight_request: @flight_request }, status: :ok
    else
      render json: { errors: @flight_request.errors }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/operations/requests/:id/process - Begin processing
  def start_process
    if @flight_request.update(status: 'under_process', processed_at: Time.current)
      AuditLog.create(
        auditable: @flight_request,
        user: current_user,
        action: 'status_change',
        changes: { status: ['under_review', 'under_process'] },
        metadata: { timestamp: Time.current }
      )
      render json: { message: 'Request under process', flight_request: @flight_request }, status: :ok
    else
      render json: { errors: @flight_request.errors }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/operations/requests/:id/unable - Mark as unable (with reason)
  def unable
    reason = params[:reason]
    return render json: { errors: ['Reason is required'] }, status: :unprocessable_entity if reason.blank?

    if @flight_request.update(status: 'unable', unable_reason: reason, unable_at: Time.current)
      AuditLog.create(
        auditable: @flight_request,
        user: current_user,
        action: 'status_change',
        changes: { status: [@flight_request.status_was, 'unable'] },
        metadata: { reason: reason, timestamp: Time.current }
      )
      render json: { message: 'Request marked as unable', flight_request: @flight_request }, status: :ok
    else
      render json: { errors: @flight_request.errors }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/operations/requests/:id/complete - Mark as complete
  def complete
    if @flight_request.update(status: 'completed', completed_at: Time.current)
      AuditLog.create(
        auditable: @flight_request,
        user: current_user,
        action: 'status_change',
        changes: { status: ['under_process', 'completed'] },
        metadata: { timestamp: Time.current }
      )
      render json: { message: 'Request completed', flight_request: @flight_request }, status: :ok
    else
      render json: { errors: @flight_request.errors }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/operations/requests/:id/modify - Update request details
  def modify
    old_attributes = @flight_request.attributes.dup
    
    if @flight_request.update(modify_params)
      changes = {}
      modify_params.keys.each do |key|
        if old_attributes[key] != @flight_request.attributes[key]
          changes[key] = [old_attributes[key], @flight_request.attributes[key]]
        end
      end

      if changes.any?
        AuditLog.create(
          auditable: @flight_request,
          user: current_user,
          action: 'modification',
          changes: changes,
          metadata: { timestamp: Time.current }
        )
      end

      render json: { message: 'Request modified successfully', flight_request: @flight_request }, status: :ok
    else
      render json: { errors: @flight_request.errors }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/operations/alerts - Get current alerts
  def alerts
    # Alerts for requests approaching deadlines
    alerts = []
    current_time = Time.current

    FlightRequest.where(status: ['sent', 'received', 'under_review', 'under_process']).each do |request|
      next unless request.flight_date

      flight_time = request.flight_date.to_time
      time_until_flight = flight_time - current_time
      hours_until_flight = time_until_flight / 1.hour

      alert_level = case hours_until_flight
                   when 0..6
                     'critical'
                   when 6..12
                     'urgent'
                   when 12..24
                     'warning'
                   when 24..48
                     'notice'
                   when 48..72
                     'info'
                   else
                     nil
                   end

      if alert_level
        alerts << {
          id: request.id,
          request_number: request.request_number,
          vip_codename: request.vip_profile.codename,
          status: request.status,
          flight_date: request.flight_date,
          hours_until_flight: hours_until_flight.round(1),
          alert_level: alert_level,
          departure_airport: request.flight_request_legs.first&.departure_airport,
          arrival_airport: request.flight_request_legs.first&.arrival_airport
        }
      end
    end

    render json: { alerts: alerts.sort_by { |a| a[:hours_until_flight] } }, status: :ok
  end

  # GET /api/v1/operations/completed_flights - List completed requests
  def completed_flights
    completed = FlightRequest.where(status: 'completed')
    
    # Apply filters
    completed = completed.where('flight_date >= ?', params[:start_date]) if params[:start_date].present?
    completed = completed.where('flight_date <= ?', params[:end_date]) if params[:end_date].present?
    completed = completed.joins(:vip_profile).where(vip_profiles: { id: params[:vip_id] }) if params[:vip_id].present?

    completed = completed.includes(:vip_profile, :flight_request_legs).page(params[:page])

    render json: {
      completed_flights: completed.map do |request|
        {
          id: request.id,
          request_number: request.request_number,
          vip_codename: request.vip_profile.codename,
          date: request.flight_date,
          passenger_count: request.number_of_passengers,
          legs: request.flight_request_legs.map do |leg|
            {
              departure_airport: leg.departure_airport,
              arrival_airport: leg.arrival_airport,
              departure_time: leg.departure_time,
              arrival_time: leg.arrival_time
            }
          end,
          completed_at: request.completed_at
        }
      end,
      pagination: {
        current_page: completed.current_page,
        total_pages: completed.total_pages,
        total_count: completed.total_count
      }
    }, status: :ok
  end

  # GET /api/v1/operations/canceled_flights - List canceled requests
  def canceled_flights
    canceled = FlightRequest.where(status: ['unable', 'deleted'])
    
    # Apply filters
    canceled = canceled.where('flight_date >= ?', params[:start_date]) if params[:start_date].present?
    canceled = canceled.where('flight_date <= ?', params[:end_date]) if params[:end_date].present?
    canceled = canceled.joins(:vip_profile).where(vip_profiles: { id: params[:vip_id] }) if params[:vip_id].present?

    canceled = canceled.includes(:vip_profile, :flight_request_legs).page(params[:page])

    render json: {
      canceled_flights: canceled.map do |request|
        {
          id: request.id,
          request_number: request.request_number,
          vip_codename: request.vip_profile.codename,
          date: request.flight_date,
          passenger_count: request.number_of_passengers,
          legs: request.flight_request_legs.map do |leg|
            {
              departure_airport: leg.departure_airport,
              arrival_airport: leg.arrival_airport,
              departure_time: leg.departure_time,
              arrival_time: leg.arrival_time
            }
          end,
          status: request.status,
          unable_reason: request.unable_reason,
          canceled_at: request.status == 'unable' ? request.unable_at : request.deleted_at
        }
      end,
      pagination: {
        current_page: canceled.current_page,
        total_pages: canceled.total_pages,
        total_count: canceled.total_count
      }
    }, status: :ok
  end

  private

  def set_flight_request
    @flight_request = FlightRequest.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Flight request not found' }, status: :not_found
  end

  def ensure_operations_staff!
    unless ['operations_staff', 'operations_admin', 'management', 'super_admin'].include?(current_user.role)
      render json: { error: 'Unauthorized' }, status: :forbidden
    end
  end

  def modify_params
    params.require(:flight_request).permit(:flight_date, :number_of_passengers, flight_request_legs_attributes: [:id, :departure_airport, :arrival_airport, :departure_time, :arrival_time, :leg_order])
  end
end
