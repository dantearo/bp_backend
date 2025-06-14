class Api::V1::AnalyticsController < ApplicationController
  before_action :require_admin_or_management

  # GET /api/v1/analytics/dashboard
  def dashboard
    timeframe = params[:timeframe] || 'week'
    
    render json: AuditAnalyticsService.dashboard_analytics(timeframe: timeframe)
  end

  # GET /api/v1/analytics/user_activity
  def user_activity
    days = (params[:days] || 30).to_i
    
    render json: AuditAnalyticsService.user_activity_patterns(days: days)
  end

  # GET /api/v1/analytics/request_lifecycle
  def request_lifecycle
    days = (params[:days] || 30).to_i
    
    render json: AuditAnalyticsService.request_lifecycle_analytics(days: days)
  end

  # GET /api/v1/analytics/system_usage
  def system_usage
    days = (params[:days] || 30).to_i
    
    render json: AuditAnalyticsService.system_usage_statistics(days: days)
  end

  # GET /api/v1/analytics/security_monitoring
  def security_monitoring
    days = (params[:days] || 7).to_i
    
    render json: AuditAnalyticsService.security_event_monitoring(days: days)
  end

  # GET /api/v1/analytics/compliance_report
  def compliance_report
    start_date = Date.parse(params[:start_date]) rescue 30.days.ago.to_date
    end_date = Date.parse(params[:end_date]) rescue Date.current
    
    render json: AuditAnalyticsService.compliance_report(
      start_date: start_date,
      end_date: end_date
    )
  end

  private

  def require_admin_or_management
    unless current_user&.role_operations_admin? || current_user&.role_management? || current_user&.role_super_admin?
      render json: { error: 'Insufficient permissions' }, status: :forbidden
    end
  end
end
