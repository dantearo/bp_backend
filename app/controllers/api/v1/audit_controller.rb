class Api::V1::AuditController < ApplicationController
  before_action :require_admin_or_management, except: [:user_activity]
  before_action :set_audit_log, only: [:show]

  # GET /api/v1/audit/logs
  def logs
    @audit_logs = AuditLog.includes(:user)
    
    apply_filters
    apply_search
    apply_sorting
    
    @pagy, @audit_logs = pagy(@audit_logs, limit: params[:per_page] || 50)
    
    render json: {
      audit_logs: serialize_audit_logs(@audit_logs),
      pagination: pagy_metadata(@pagy),
      filters_applied: applied_filters_summary
    }
  end

  # GET /api/v1/audit/logs/:id
  def show
    render json: {
      audit_log: serialize_audit_log(@audit_log, detailed: true)
    }
  end

  # GET /api/v1/audit/user_activity/:user_id
  def user_activity
    @user = User.find(params[:user_id])
    
    # Check permissions - users can only see their own activity unless admin/management
    unless current_user == @user || admin_or_management?
      render json: { error: 'Unauthorized' }, status: :forbidden
      return
    end

    days = (params[:days] || 30).to_i
    @audit_logs = AuditLog.where(user: @user)
                          .where(created_at: days.days.ago..Time.current)
                          .order(created_at: :desc)

    apply_activity_filters

    @pagy, @audit_logs = pagy(@audit_logs, limit: params[:per_page] || 25)

    render json: {
      user: {
        id: @user.id,
        email: @user.email,
        role: @user.role
      },
      activity_summary: AuthenticationAuditService.user_activity_summary(user: @user, days: days),
      audit_logs: serialize_audit_logs(@audit_logs),
      pagination: pagy_metadata(@pagy)
    }
  end

  # GET /api/v1/audit/request_history/:request_id
  def request_history
    @flight_request = FlightRequest.find(params[:request_id])
    
    @audit_logs = AuditLog.where(
      resource_type: 'FlightRequest',
      resource_id: @flight_request.id
    ).order(created_at: :asc)

    render json: {
      flight_request: {
        id: @flight_request.id,
        request_number: @flight_request.request_number,
        current_status: @flight_request.status
      },
      history: serialize_audit_logs(@audit_logs),
      timeline: build_request_timeline(@audit_logs)
    }
  end

  # GET /api/v1/audit/export
  def export
    @audit_logs = AuditLog.includes(:user)
    apply_filters
    apply_search

    # Limit export to prevent system overload
    if @audit_logs.count > 10000
      render json: { 
        error: 'Export too large',
        message: 'Please apply filters to reduce the dataset. Maximum 10,000 records allowed for export.',
        current_count: @audit_logs.count
      }, status: :bad_request
      return
    end

    case params[:format]&.downcase
    when 'csv'
      export_csv
    when 'json'
      export_json
    else
      render json: { error: 'Unsupported format. Use csv or json.' }, status: :bad_request
    end
  end

  # GET /api/v1/audit/security_events
  def security_events
    hours = (params[:hours] || 24).to_i
    
    security_events = {
      login_failures: AuthenticationAuditService.recent_login_failures(hours).count,
      suspicious_ips: AuthenticationAuditService.suspicious_ip_addresses(hours),
      recent_lockouts: recent_account_lockouts(hours),
      unusual_activity: detect_unusual_activity(hours)
    }

    render json: {
      time_period: "Last #{hours} hours",
      security_summary: security_events,
      recommendations: generate_security_recommendations(security_events)
    }
  end

  private

  def set_audit_log
    @audit_log = AuditLog.find(params[:id])
  end

  def require_admin_or_management
    unless admin_or_management?
      render json: { error: 'Insufficient permissions' }, status: :forbidden
    end
  end

  def admin_or_management?
    current_user&.role_operations_admin? || current_user&.role_management? || current_user&.role_super_admin?
  end

  def apply_filters
    @audit_logs = @audit_logs.where(user_id: params[:user_id]) if params[:user_id].present?
    @audit_logs = @audit_logs.where(action_type: params[:action_type]) if params[:action_type].present?
    @audit_logs = @audit_logs.where(resource_type: params[:resource_type]) if params[:resource_type].present?
    @audit_logs = @audit_logs.where(resource_id: params[:resource_id]) if params[:resource_id].present?
    @audit_logs = @audit_logs.where(ip_address: params[:ip_address]) if params[:ip_address].present?
    
    if params[:start_date].present?
      @audit_logs = @audit_logs.where('created_at >= ?', Date.parse(params[:start_date]))
    end
    
    if params[:end_date].present?
      @audit_logs = @audit_logs.where('created_at <= ?', Date.parse(params[:end_date]).end_of_day)
    end
  end

  def apply_search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @audit_logs = @audit_logs.left_joins(:user).where(
        "users.email ILIKE ? OR audit_logs.ip_address ILIKE ? OR audit_logs.user_agent ILIKE ? OR audit_logs.metadata::text ILIKE ?",
        search_term, search_term, search_term, search_term
      )
    end
  end

  def apply_sorting
    case params[:sort]
    when 'user'
      @audit_logs = @audit_logs.left_joins(:user).order('users.email ASC')
    when 'action'
      @audit_logs = @audit_logs.order(:action_type)
    when 'resource'
      @audit_logs = @audit_logs.order(:resource_type, :resource_id)
    else
      @audit_logs = @audit_logs.order(created_at: :desc)
    end
  end

  def apply_activity_filters
    @audit_logs = @audit_logs.where(action_type: params[:action_type]) if params[:action_type].present?
    @audit_logs = @audit_logs.where(resource_type: params[:resource_type]) if params[:resource_type].present?
  end

  def serialize_audit_logs(audit_logs)
    audit_logs.map { |log| serialize_audit_log(log) }
  end

  def serialize_audit_log(audit_log, detailed: false)
    base_data = {
      id: audit_log.id,
      user: audit_log.user ? {
        id: audit_log.user.id,
        email: audit_log.user.email,
        role: audit_log.user.role
      } : nil,
      action_type: audit_log.action_type,
      resource_type: audit_log.resource_type,
      resource_id: audit_log.resource_id,
      ip_address: audit_log.ip_address,
      user_agent: audit_log.user_agent,
      created_at: audit_log.created_at.iso8601
    }

    if detailed
      base_data[:metadata] = audit_log.metadata
    else
      base_data[:summary] = extract_summary_from_metadata(audit_log.metadata)
    end

    base_data
  end

  def extract_summary_from_metadata(metadata)
    return nil unless metadata.present?

    {
      event_type: metadata['event_type'],
      status: metadata.dig('response', 'status'),
      duration: metadata.dig('performance', 'duration_ms')
    }
  end

  def applied_filters_summary
    filters = {}
    filters[:user_id] = params[:user_id] if params[:user_id].present?
    filters[:action_type] = params[:action_type] if params[:action_type].present?
    filters[:resource_type] = params[:resource_type] if params[:resource_type].present?
    filters[:date_range] = "#{params[:start_date]} to #{params[:end_date]}" if params[:start_date].present? || params[:end_date].present?
    filters[:search] = params[:search] if params[:search].present?
    filters
  end

  def build_request_timeline(audit_logs)
    audit_logs.map do |log|
      {
        timestamp: log.created_at.iso8601,
        action: log.action_type,
        user: log.user&.email || 'System',
        description: build_action_description(log),
        metadata: log.metadata&.except('request', 'response') # Exclude verbose request/response data
      }
    end
  end

  def build_action_description(log)
    case log.action_type
    when 'create'
      "#{log.resource_type} created"
    when 'update'
      if log.metadata&.dig('event_type') == 'status_change'
        old_status = log.metadata&.dig('changes', 'status', 0)
        new_status = log.metadata&.dig('changes', 'status', 1)
        "Status changed from #{old_status} to #{new_status}"
      else
        "#{log.resource_type} updated"
      end
    when 'delete'
      "#{log.resource_type} deleted"
    when 'status_change'
      "Status updated"
    else
      log.action_type.humanize
    end
  end

  def export_csv
    require 'csv'
    
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['ID', 'User Email', 'Action', 'Resource Type', 'Resource ID', 'IP Address', 'User Agent', 'Created At']
      
      @audit_logs.includes(:user).find_each do |log|
        csv << [
          log.id,
          log.user&.email,
          log.action_type,
          log.resource_type,
          log.resource_id,
          log.ip_address,
          log.user_agent,
          log.created_at.iso8601
        ]
      end
    end

    send_data csv_data, 
              filename: "audit_logs_#{Date.current}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end

  def export_json
    data = {
      export_info: {
        generated_at: Time.current.iso8601,
        total_records: @audit_logs.count,
        filters_applied: applied_filters_summary
      },
      audit_logs: serialize_audit_logs(@audit_logs.includes(:user))
    }

    send_data data.to_json,
              filename: "audit_logs_#{Date.current}.json",
              type: 'application/json',
              disposition: 'attachment'
  end

  def recent_account_lockouts(hours)
    AuditLog.where(
      resource_type: 'Account',
      created_at: hours.hours.ago..Time.current
    ).where(
      "metadata ->> 'event_type' = ?", 'account_lockout'
    ).count
  end

  def detect_unusual_activity(hours)
    # Detect unusual patterns in the specified time period
    {
      high_volume_users: detect_high_volume_users(hours),
      unusual_ip_patterns: detect_unusual_ip_patterns(hours),
      off_hours_activity: detect_off_hours_activity(hours)
    }
  end

  def detect_high_volume_users(hours)
    AuditLog.where(created_at: hours.hours.ago..Time.current)
            .joins(:user)
            .group('users.email')
            .having('COUNT(*) > ?', 100)
            .count
  end

  def detect_unusual_ip_patterns(hours)
    AuditLog.where(created_at: hours.hours.ago..Time.current)
            .group(:ip_address)
            .having('COUNT(DISTINCT user_id) > ?', 5)
            .count
  end

  def detect_off_hours_activity(hours)
    # Activity outside business hours (assuming 6 AM - 6 PM local time)
    AuditLog.where(created_at: hours.hours.ago..Time.current)
            .where("EXTRACT(hour FROM created_at) < 6 OR EXTRACT(hour FROM created_at) > 18")
            .count
  end

  def generate_security_recommendations(security_events)
    recommendations = []
    
    if security_events[:login_failures] > 10
      recommendations << "High number of login failures detected. Consider implementing additional security measures."
    end
    
    if security_events[:suspicious_ips].any?
      recommendations << "Suspicious IP addresses detected with multiple failed login attempts. Consider IP blocking."
    end
    
    if security_events[:recent_lockouts] > 0
      recommendations << "Account lockouts detected. Review and investigate affected accounts."
    end
    
    if security_events[:unusual_activity][:high_volume_users].any?
      recommendations << "High-volume user activity detected. Verify legitimate business use."
    end

    recommendations.empty? ? ["No immediate security concerns detected."] : recommendations
  end

  def pagy_metadata(pagy)
    {
      current_page: pagy.page,
      total_pages: pagy.pages,
      total_count: pagy.count,
      per_page: pagy.vars[:limit],
      next_page: pagy.next,
      prev_page: pagy.prev
    }
  end
end
