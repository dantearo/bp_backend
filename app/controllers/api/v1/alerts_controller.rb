class Api::V1::AlertsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_alert, only: [:show, :update]

  def index
    alerts = current_user.alerts
                        .includes(:flight_request, :acknowledged_by, :notifications)
                        .by_priority

    # Filter by status if provided
    alerts = alerts.where(status: params[:status]) if params[:status].present?
    
    # Filter by alert type if provided
    alerts = alerts.where(alert_type: params[:alert_type]) if params[:alert_type].present?

    # Pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 20

    alerts = alerts.page(page).per(per_page)

    render json: {
      alerts: alerts.map { |alert| serialize_alert(alert) },
      meta: {
        current_page: alerts.current_page,
        total_pages: alerts.total_pages,
        total_count: alerts.total_count,
        per_page: per_page
      }
    }
  end

  def show
    render json: serialize_alert(@alert)
  end

  def update
    case params[:action_type]
    when 'acknowledge'
      acknowledge_alert
    when 'dismiss'
      dismiss_alert
    else
      render json: { error: 'Invalid action type' }, status: :bad_request
    end
  end

  def dashboard
    render json: {
      summary: {
        total_alerts: current_user.alerts.count,
        unacknowledged: current_user.alerts.unacknowledged.count,
        critical: current_user.alerts.where(priority: :critical).count,
        by_type: alert_counts_by_type,
        by_priority: alert_counts_by_priority
      },
      recent_alerts: current_user.alerts
                                .includes(:flight_request)
                                .by_priority
                                .limit(10)
                                .map { |alert| serialize_alert(alert) },
      flight_alerts: get_upcoming_flight_alerts
    }
  end

  private

  def set_alert
    @alert = current_user.alerts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Alert not found' }, status: :not_found
  end

  def acknowledge_alert
    if @alert.acknowledge!(current_user)
      render json: { 
        message: 'Alert acknowledged successfully',
        alert: serialize_alert(@alert)
      }
    else
      render json: { error: 'Failed to acknowledge alert' }, status: :unprocessable_entity
    end
  end

  def dismiss_alert
    if @alert.update(status: :dismissed)
      render json: { 
        message: 'Alert dismissed successfully',
        alert: serialize_alert(@alert)
      }
    else
      render json: { error: 'Failed to dismiss alert' }, status: :unprocessable_entity
    end
  end

  def serialize_alert(alert)
    {
      id: alert.id,
      alert_type: alert.alert_type,
      title: alert.title,
      message: alert.message,
      priority: alert.priority,
      status: alert.status,
      created_at: alert.created_at,
      acknowledged_at: alert.acknowledged_at,
      acknowledged_by: alert.acknowledged_by&.full_name,
      escalated_at: alert.escalated_at,
      escalation_level: alert.escalation_level,
      metadata: alert.metadata,
      flight_request: {
        id: alert.flight_request.id,
        request_number: alert.flight_request.request_number,
        status: alert.flight_request.status,
        vip_codename: alert.flight_request.vip_profile.codename,
        flight_date: alert.flight_request.flight_date
      },
      hours_until_flight: alert.hours_until_flight,
      notifications_count: alert.notifications.count
    }
  end

  def alert_counts_by_type
    current_user.alerts.group(:alert_type).count
  end

  def alert_counts_by_priority
    current_user.alerts.group(:priority).count
  end

  def get_upcoming_flight_alerts
    # Get flight requests with upcoming departures
    upcoming_flights = FlightRequest.joins(:flight_request_legs)
                                  .where(flight_request_legs: { departure_time: Time.current..3.days.from_now })
                                  .includes(:vip_profile, :alerts)
                                  .distinct

    upcoming_flights.map do |flight|
      earliest_departure = flight.flight_request_legs.minimum(:departure_time)
      hours_until = ((earliest_departure - Time.current) / 1.hour).round(1) if earliest_departure

      {
        flight_request_id: flight.id,
        request_number: flight.request_number,
        vip_codename: flight.vip_profile.codename,
        hours_until_departure: hours_until,
        status: flight.status,
        alert_count: flight.alerts.unacknowledged.count,
        has_critical_alerts: flight.alerts.where(priority: :critical).unacknowledged.exists?
      }
    end.sort_by { |f| f[:hours_until_departure] || Float::INFINITY }
  end

  def authenticate_user!
    # Placeholder for authentication logic
    # This should be implemented based on your authentication system
    render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user
  end

  def current_user
    # Placeholder - implement based on your authentication system
    # For now, return the first operations staff user for testing
    @current_user ||= User.where(role: [:operations_staff, :operations_admin]).first
  end
end
