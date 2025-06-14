class ManagementDashboardService
  def initialize
    @date_range = 30.days.ago..Time.current
  end

  def generate_dashboard_data(date_range: nil, filters: {})
    @date_range = parse_date_range(date_range) if date_range
    @filters = filters.compact

    {
      kpis: generate_kpis,
      request_status_summary: generate_request_status_summary,
      user_activity_overview: generate_user_activity_overview,
      system_health_metrics: generate_system_health_metrics,
      recent_activity: generate_recent_activity,
      period: {
        start_date: @date_range.begin,
        end_date: @date_range.end,
        days: (@date_range.end - @date_range.begin).to_i / 1.day
      }
    }
  end

  private

  def generate_kpis
    flight_requests = filtered_flight_requests

    {
      total_requests: flight_requests.count,
      active_requests: flight_requests.where(status: %w[sent received under_review processing]).count,
      completed_requests: flight_requests.where(status: "completed").count,
      canceled_requests: flight_requests.where(status: %w[canceled unable]).count,
      average_processing_time: calculate_average_processing_time(flight_requests),
      completion_rate: calculate_completion_rate(flight_requests),
      vip_requests: flight_requests.joins(:vip_profile).count,
      urgent_requests: flight_requests.where(priority: "urgent").count
    }
  end

  def generate_request_status_summary
    status_counts = filtered_flight_requests
                   .group(:status)
                   .count
                   .transform_keys { |k| k.humanize.titleize }

    {
      status_distribution: status_counts,
      total_requests: status_counts.values.sum,
      status_percentages: calculate_status_percentages(status_counts)
    }
  end

  def generate_user_activity_overview
    {
      active_users_count: User.joins(:flight_requests)
                             .where(flight_requests: { created_at: @date_range })
                             .distinct
                             .count,
      top_request_sources: User.joins(:source_flight_requests)
                              .where(flight_requests: { created_at: @date_range })
                              .group("users.name")
                              .count
                              .sort_by { |_, count| -count }
                              .first(5)
                              .to_h,
      operations_staff_workload: User.where(role: %w[operations_staff operations_admin])
                                    .joins(:assigned_flight_requests)
                                    .where(flight_requests: { created_at: @date_range })
                                    .group("users.name")
                                    .count
                                    .sort_by { |_, count| -count }
                                    .to_h
    }
  end

  def generate_system_health_metrics
    {
      database_size: calculate_database_size,
      total_flight_requests: FlightRequest.count,
      total_vip_profiles: VipProfile.count,
      total_users: User.count,
      audit_logs_count: AuditLog.where(created_at: @date_range).count,
      system_alerts: generate_system_alerts,
      average_response_time: calculate_average_response_time
    }
  end

  def generate_recent_activity
    FlightRequest.includes(:vip_profile, :source_of_request_user)
                 .where(created_at: @date_range)
                 .order(created_at: :desc)
                 .limit(10)
                 .map do |request|
      {
        id: request.id,
        request_number: request.request_number,
        status: request.status.humanize,
        vip_name: request.vip_profile&.codename || "Unknown VIP",
        created_at: request.created_at,
        source_user: request.source_of_request_user&.name || "Unknown User",
        priority: request.priority
      }
    end
  end

  def filtered_flight_requests
    scope = FlightRequest.where(created_at: @date_range)

    scope = scope.where(status: @filters[:status]) if @filters[:status]
    scope = scope.where(vip_profile_id: @filters[:vip_profile_id]) if @filters[:vip_profile_id]
    scope = scope.where(source_of_request_user_id: @filters[:source_user_id]) if @filters[:source_user_id]

    scope
  end

  def calculate_average_processing_time(requests)
    completed_requests = requests.where(status: "completed")
                               .where.not(processed_at: nil)

    return 0 if completed_requests.empty?

    total_time = completed_requests.sum do |request|
      (request.processed_at - request.created_at).to_i
    end

    (total_time.to_f / completed_requests.count / 3600).round(2) # Convert to hours
  end

  def calculate_completion_rate(requests)
    return 0 if requests.empty?

    completed_count = requests.where(status: "completed").count
    (completed_count.to_f / requests.count * 100).round(2)
  end

  def calculate_status_percentages(status_counts)
    total = status_counts.values.sum
    return {} if total.zero?

    status_counts.transform_values do |count|
      (count.to_f / total * 100).round(2)
    end
  end

  def calculate_database_size
    # This is a placeholder - actual implementation would depend on database type
    "N/A - Implementation needed for #{Rails.configuration.database_configuration[Rails.env]['adapter']}"
  end

  def generate_system_alerts
    alerts = []

    # Check for old pending requests
    old_requests = FlightRequest.where(status: %w[sent received])
                               .where("created_at < ?", 48.hours.ago)
                               .count

    if old_requests > 0
      alerts << {
        type: "warning",
        message: "#{old_requests} requests pending for more than 48 hours",
        count: old_requests
      }
    end

    # Check for high priority requests
    urgent_requests = FlightRequest.where(status: %w[sent received under_review])
                                  .where(priority: "urgent")
                                  .count

    if urgent_requests > 0
      alerts << {
        type: "urgent",
        message: "#{urgent_requests} urgent requests require attention",
        count: urgent_requests
      }
    end

    alerts
  end

  def calculate_average_response_time
    # This would be implemented based on actual response time tracking
    # For now, return a placeholder
    "Response time tracking not implemented"
  end

  def parse_date_range(date_range)
    case date_range
    when "today"
      Date.current.beginning_of_day..Date.current.end_of_day
    when "week"
      1.week.ago..Time.current
    when "month"
      1.month.ago..Time.current
    when "quarter"
      3.months.ago..Time.current
    when "year"
      1.year.ago..Time.current
    else
      30.days.ago..Time.current
    end
  end
end
