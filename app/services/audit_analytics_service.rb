class AuditAnalyticsService
  class << self
    # User Activity Patterns
    def user_activity_patterns(days: 30)
      start_date = days.days.ago
      
      {
        overview: {
          total_users: User.count,
          active_users: active_users_count(start_date),
          total_actions: AuditLog.where(created_at: start_date..Time.current).count,
          unique_sessions: unique_sessions_count(start_date)
        },
        activity_by_role: activity_by_role(start_date),
        peak_usage_times: peak_usage_analysis(start_date),
        user_engagement: user_engagement_metrics(start_date),
        geographic_distribution: geographic_activity_analysis(start_date)
      }
    end

    # Request Lifecycle Analytics
    def request_lifecycle_analytics(days: 30)
      start_date = days.days.ago
      
      {
        overview: {
          total_requests: FlightRequest.where(created_at: start_date..Time.current).count,
          completed_requests: completed_requests_count(start_date),
          average_processing_time: average_request_processing_time(start_date),
          status_distribution: request_status_distribution(start_date)
        },
        processing_efficiency: processing_efficiency_metrics(start_date),
        bottleneck_analysis: identify_processing_bottlenecks(start_date),
        completion_trends: request_completion_trends(start_date),
        failure_analysis: request_failure_analysis(start_date)
      }
    end

    # System Usage Statistics
    def system_usage_statistics(days: 30)
      start_date = days.days.ago
      
      {
        overview: {
          total_api_calls: total_api_calls_count(start_date),
          average_response_time: average_api_response_time(start_date),
          error_rate: api_error_rate(start_date),
          peak_concurrent_users: peak_concurrent_users(start_date)
        },
        endpoint_usage: endpoint_usage_analysis(start_date),
        performance_metrics: api_performance_metrics(start_date),
        resource_utilization: resource_utilization_analysis(start_date),
        growth_trends: usage_growth_trends(start_date)
      }
    end

    # Security Event Monitoring
    def security_event_monitoring(days: 7)
      start_date = days.days.ago
      
      {
        threat_summary: {
          total_security_events: security_events_count(start_date),
          high_priority_alerts: high_priority_security_alerts(start_date),
          blocked_attempts: blocked_access_attempts(start_date),
          successful_breaches: 0 # Placeholder - would integrate with security systems
        },
        authentication_security: authentication_security_analysis(start_date),
        access_anomalies: detect_access_anomalies(start_date),
        ip_analysis: suspicious_ip_analysis(start_date),
        user_behavior_anomalies: detect_user_behavior_anomalies(start_date)
      }
    end

    # Compliance and Audit Reporting
    def compliance_report(start_date:, end_date:)
      {
        report_period: {
          start_date: start_date.to_date,
          end_date: end_date.to_date,
          total_days: (end_date.to_date - start_date.to_date).to_i
        },
        audit_completeness: audit_log_completeness(start_date, end_date),
        user_access_review: user_access_compliance(start_date, end_date),
        data_retention: data_retention_compliance(start_date, end_date),
        security_incidents: security_incidents_summary(start_date, end_date),
        recommendations: generate_compliance_recommendations(start_date, end_date)
      }
    end

    # Advanced Analytics Dashboard Data
    def dashboard_analytics(timeframe: 'week')
      case timeframe
      when 'day'
        days = 1
        intervals = generate_hourly_intervals(days)
      when 'week'
        days = 7
        intervals = generate_daily_intervals(days)
      when 'month'
        days = 30
        intervals = generate_daily_intervals(days)
      else
        days = 7
        intervals = generate_daily_intervals(days)
      end

      {
        timeframe: timeframe,
        summary_metrics: dashboard_summary_metrics(days),
        activity_timeline: activity_timeline_data(intervals),
        user_insights: user_insights_data(days),
        system_health: system_health_metrics(days),
        alerts: current_system_alerts
      }
    end

    private

    # User Activity Helpers
    def active_users_count(start_date)
      AuditLog.where(created_at: start_date..Time.current)
              .distinct
              .count(:user_id)
    end

    def unique_sessions_count(start_date)
      # Estimate based on login events and session duration
      AuditLog.where(
        action_type: 'login',
        created_at: start_date..Time.current
      ).count
    end

    def activity_by_role(start_date)
      AuditLog.joins(:user)
              .where(created_at: start_date..Time.current)
              .group('users.role')
              .count
    end

    def peak_usage_analysis(start_date)
      hourly_activity = AuditLog.where(created_at: start_date..Time.current)
                               .group_by_hour(:created_at, time_zone: 'UTC')
                               .count

      daily_activity = AuditLog.where(created_at: start_date..Time.current)
                              .group_by_day(:created_at, time_zone: 'UTC')
                              .count

      {
        peak_hour: hourly_activity.max_by { |_, count| count }&.first,
        peak_day: daily_activity.max_by { |_, count| count }&.first,
        hourly_distribution: hourly_activity,
        daily_distribution: daily_activity
      }
    end

    def user_engagement_metrics(start_date)
      user_activity = AuditLog.joins(:user)
                             .where(created_at: start_date..Time.current)
                             .group('users.id', 'users.email')
                             .count

      {
        highly_active_users: user_activity.select { |_, count| count > 100 }.count,
        moderately_active_users: user_activity.select { |_, count| count.between?(10, 100) }.count,
        low_active_users: user_activity.select { |_, count| count < 10 }.count,
        top_users: user_activity.sort_by { |_, count| -count }.first(10)
      }
    end

    def geographic_activity_analysis(start_date)
      ip_activity = AuditLog.where(created_at: start_date..Time.current)
                           .where.not(ip_address: nil)
                           .group(:ip_address)
                           .count

      # Placeholder for IP geolocation analysis
      {
        unique_ips: ip_activity.keys.count,
        top_ips: ip_activity.sort_by { |_, count| -count }.first(10),
        geographic_note: "Geographic analysis requires IP geolocation service integration"
      }
    end

    # Request Lifecycle Helpers
    def completed_requests_count(start_date)
      FlightRequest.where(
        created_at: start_date..Time.current,
        status: 'completed'
      ).count
    end

    def average_request_processing_time(start_date)
      # Calculate average time from creation to completion
      completed_requests = FlightRequest.where(
        created_at: start_date..Time.current,
        status: 'completed'
      )

      return 0 if completed_requests.empty?

      total_time = completed_requests.sum do |request|
        creation_log = AuditLog.where(
          resource_type: 'FlightRequest',
          resource_id: request.id,
          action_type: 'create'
        ).first

        completion_log = AuditLog.where(
          resource_type: 'FlightRequest',
          resource_id: request.id,
          action_type: 'status_change'
        ).where(
          "metadata ->> 'changes' LIKE ?", '%completed%'
        ).first

        if creation_log && completion_log
          (completion_log.created_at - creation_log.created_at) / 1.hour
        else
          0
        end
      end

      (total_time / completed_requests.count).round(2)
    end

    def request_status_distribution(start_date)
      FlightRequest.where(created_at: start_date..Time.current)
                  .group(:status)
                  .count
    end

    def processing_efficiency_metrics(start_date)
      requests = FlightRequest.where(created_at: start_date..Time.current)
      
      {
        on_time_completion_rate: calculate_on_time_completion_rate(requests),
        average_status_changes: calculate_average_status_changes(requests),
        requests_requiring_rework: count_requests_with_rework(requests)
      }
    end

    def identify_processing_bottlenecks(start_date)
      status_changes = AuditLog.where(
        action_type: 'status_change',
        created_at: start_date..Time.current
      )

      status_durations = {}
      
      status_changes.group_by(&:resource_id).each do |request_id, changes|
        changes.sort_by(&:created_at).each_cons(2) do |current, next_change|
          current_status = current.metadata&.dig('changes', 'status', 1)
          duration = (next_change.created_at - current.created_at) / 1.hour
          
          status_durations[current_status] ||= []
          status_durations[current_status] << duration
        end
      end

      status_durations.transform_values do |durations|
        {
          average_duration: (durations.sum / durations.count).round(2),
          median_duration: durations.sort[durations.count / 2].round(2),
          max_duration: durations.max.round(2)
        }
      end
    end

    def request_completion_trends(start_date)
      AuditLog.where(
        action_type: 'status_change',
        created_at: start_date..Time.current
      ).where(
        "metadata ->> 'changes' LIKE ?", '%completed%'
      ).group_by_day(:created_at, time_zone: 'UTC')
       .count
    end

    def request_failure_analysis(start_date)
      failed_requests = AuditLog.where(
        action_type: 'status_change',
        created_at: start_date..Time.current
      ).where(
        "metadata ->> 'changes' LIKE ?", '%cancelled%'
      )

      {
        total_failures: failed_requests.count,
        failure_reasons: extract_failure_reasons(failed_requests),
        failure_trends: failed_requests.group_by_day(:created_at, time_zone: 'UTC').count
      }
    end

    # System Usage Helpers
    def total_api_calls_count(start_date)
      AuditLog.where(
        created_at: start_date..Time.current,
        action_type: 'read'
      ).count
    end

    def average_api_response_time(start_date)
      response_times = AuditLog.where(created_at: start_date..Time.current)
                              .where.not("metadata ->> 'performance' IS NULL")
                              .pluck("metadata -> 'performance' ->> 'duration_ms'")
                              .compact
                              .map(&:to_f)

      return 0 if response_times.empty?
      (response_times.sum / response_times.count).round(2)
    end

    def api_error_rate(start_date)
      total_requests = AuditLog.where(created_at: start_date..Time.current).count
      return 0 if total_requests.zero?

      error_requests = AuditLog.where(created_at: start_date..Time.current)
                              .where("metadata -> 'response' ->> 'status' >= '400'")
                              .count

      ((error_requests.to_f / total_requests) * 100).round(2)
    end

    def peak_concurrent_users(start_date)
      # Estimate concurrent users based on overlapping sessions
      # This is a simplified estimation
      daily_peaks = AuditLog.where(
        action_type: 'login',
        created_at: start_date..Time.current
      ).group_by_day(:created_at, time_zone: 'UTC')
       .count

      daily_peaks.values.max || 0
    end

    def endpoint_usage_analysis(start_date)
      AuditLog.where(created_at: start_date..Time.current)
              .where.not("metadata -> 'request' ->> 'path' IS NULL")
              .group("metadata -> 'request' ->> 'path'")
              .count
              .sort_by { |_, count| -count }
              .first(20)
              .to_h
    end

    def api_performance_metrics(start_date)
      logs_with_performance = AuditLog.where(created_at: start_date..Time.current)
                                     .where.not("metadata ->> 'performance' IS NULL")

      response_times = logs_with_performance.pluck("metadata -> 'performance' ->> 'duration_ms'")
                                          .compact
                                          .map(&:to_f)

      return {} if response_times.empty?

      sorted_times = response_times.sort
      {
        average_response_time: (response_times.sum / response_times.count).round(2),
        median_response_time: sorted_times[sorted_times.count / 2].round(2),
        p95_response_time: sorted_times[(sorted_times.count * 0.95).to_i].round(2),
        p99_response_time: sorted_times[(sorted_times.count * 0.99).to_i].round(2)
      }
    end

    def resource_utilization_analysis(start_date)
      resource_activity = AuditLog.where(created_at: start_date..Time.current)
                                 .group(:resource_type)
                                 .group(:action_type)
                                 .count

      {
        most_accessed_resources: resource_activity.sort_by { |_, count| -count }.first(10),
        crud_distribution: resource_activity.group_by { |(_, action), _| action }
                                           .transform_values { |entries| entries.sum { |_, count| count } }
      }
    end

    def usage_growth_trends(start_date)
      daily_usage = AuditLog.where(created_at: start_date..Time.current)
                           .group_by_day(:created_at, time_zone: 'UTC')
                           .count

      return {} if daily_usage.empty?

      values = daily_usage.values
      if values.count > 1
        growth_rate = ((values.last - values.first).to_f / values.first * 100).round(2)
      else
        growth_rate = 0
      end

      {
        daily_usage_trend: daily_usage,
        overall_growth_rate: growth_rate,
        trend_direction: growth_rate > 0 ? 'increasing' : growth_rate < 0 ? 'decreasing' : 'stable'
      }
    end

    # Security Monitoring Helpers
    def security_events_count(start_date)
      AuditLog.where(
        created_at: start_date..Time.current,
        action_type: 'login'
      ).where(
        "metadata ->> 'event_type' = ?", 'login_failure'
      ).count
    end

    def high_priority_security_alerts(start_date)
      AuthenticationAuditService.suspicious_ip_addresses(((Time.current - start_date) / 1.hour).to_i).count
    end

    def blocked_access_attempts(start_date)
      AuditLog.where(
        created_at: start_date..Time.current,
        resource_type: 'Account'
      ).where(
        "metadata ->> 'event_type' = ?", 'account_lockout'
      ).count
    end

    def authentication_security_analysis(start_date)
      login_attempts = AuditLog.where(
        action_type: 'login',
        created_at: start_date..Time.current
      )

      successful_logins = login_attempts.where("metadata ->> 'event_type' = ?", 'login_success').count
      failed_logins = login_attempts.where("metadata ->> 'event_type' = ?", 'login_failure').count

      {
        total_login_attempts: login_attempts.count,
        successful_logins: successful_logins,
        failed_logins: failed_logins,
        success_rate: successful_logins + failed_logins > 0 ? 
          ((successful_logins.to_f / (successful_logins + failed_logins)) * 100).round(2) : 0
      }
    end

    def detect_access_anomalies(start_date)
      {
        unusual_access_times: detect_unusual_access_times(start_date),
        multiple_location_access: detect_multiple_location_access(start_date),
        rapid_successive_attempts: detect_rapid_successive_attempts(start_date)
      }
    end

    def suspicious_ip_analysis(start_date)
      AuthenticationAuditService.suspicious_ip_addresses(((Time.current - start_date) / 1.hour).to_i)
    end

    def detect_user_behavior_anomalies(start_date)
      users_with_unusual_activity = AuditLog.joins(:user)
                                           .where(created_at: start_date..Time.current)
                                           .group('users.id', 'users.email')
                                           .having('COUNT(*) > ?', 200)
                                           .count

      {
        high_activity_users: users_with_unusual_activity.count,
        details: users_with_unusual_activity.first(5)
      }
    end

    # Dashboard Helpers
    def dashboard_summary_metrics(days)
      start_date = days.days.ago
      
      {
        total_users: User.count,
        active_users: active_users_count(start_date),
        total_requests: FlightRequest.where(created_at: start_date..Time.current).count,
        completed_requests: completed_requests_count(start_date),
        security_events: security_events_count(start_date),
        system_uptime: calculate_system_uptime(start_date)
      }
    end

    def activity_timeline_data(intervals)
      intervals.map do |interval|
        {
          timestamp: interval[:start],
          user_activity: AuditLog.joins(:user)
                                .where(created_at: interval[:start]..interval[:end])
                                .count,
          api_calls: AuditLog.where(created_at: interval[:start]..interval[:end])
                            .count,
          security_events: AuditLog.where(
                            created_at: interval[:start]..interval[:end],
                            action_type: 'login'
                          ).where(
                            "metadata ->> 'event_type' = ?", 'login_failure'
                          ).count
        }
      end
    end

    def user_insights_data(days)
      start_date = days.days.ago
      
      {
        new_users: User.where(created_at: start_date..Time.current).count,
        user_retention: calculate_user_retention(start_date),
        role_distribution: User.group(:role).count,
        most_active_users: most_active_users(start_date, limit: 5)
      }
    end

    def system_health_metrics(days)
      start_date = days.days.ago
      
      {
        average_response_time: average_api_response_time(start_date),
        error_rate: api_error_rate(start_date),
        uptime_percentage: calculate_uptime_percentage(start_date),
        database_health: assess_database_health(start_date)
      }
    end

    def current_system_alerts
      [
        # Placeholder for real-time alerts
        # Would integrate with monitoring systems
      ]
    end

    # Utility Methods
    def generate_hourly_intervals(days)
      start_time = days.days.ago.beginning_of_hour
      intervals = []
      
      (0...(days * 24)).each do |hour_offset|
        interval_start = start_time + hour_offset.hours
        intervals << {
          start: interval_start,
          end: interval_start + 1.hour - 1.second
        }
      end
      
      intervals
    end

    def generate_daily_intervals(days)
      start_date = days.days.ago.beginning_of_day
      intervals = []
      
      (0...days).each do |day_offset|
        interval_start = start_date + day_offset.days
        intervals << {
          start: interval_start,
          end: interval_start.end_of_day
        }
      end
      
      intervals
    end

    def calculate_system_uptime(start_date)
      # Simplified uptime calculation based on successful API responses
      total_requests = AuditLog.where(created_at: start_date..Time.current).count
      return 100.0 if total_requests.zero?

      successful_requests = AuditLog.where(created_at: start_date..Time.current)
                                   .where("metadata -> 'response' ->> 'status' < '400'")
                                   .count

      ((successful_requests.to_f / total_requests) * 100).round(2)
    end

    def calculate_user_retention(start_date)
      users_at_start = User.where(created_at: ..start_date).count
      return 0 if users_at_start.zero?

      active_existing_users = AuditLog.joins(:user)
                                     .where(users: { created_at: ..start_date })
                                     .where(audit_logs: { created_at: start_date..Time.current })
                                     .distinct
                                     .count('users.id')

      ((active_existing_users.to_f / users_at_start) * 100).round(2)
    end

    def most_active_users(start_date, limit: 10)
      AuditLog.joins(:user)
              .where(created_at: start_date..Time.current)
              .group('users.id', 'users.email', 'users.role')
              .order('COUNT(*) DESC')
              .limit(limit)
              .count
              .map do |(id, email, role), count|
                {
                  user_id: id,
                  email: email,
                  role: role,
                  activity_count: count
                }
              end
    end

    def calculate_uptime_percentage(start_date)
      calculate_system_uptime(start_date)
    end

    def assess_database_health(start_date)
      # Simplified database health assessment
      recent_logs = AuditLog.where(created_at: 1.hour.ago..Time.current).count
      
      {
        recent_activity: recent_logs,
        status: recent_logs > 0 ? 'healthy' : 'warning',
        last_activity: AuditLog.maximum(:created_at)
      }
    end

    # Placeholder methods for complex calculations
    def calculate_on_time_completion_rate(requests)
      # Placeholder - would need SLA definitions
      75.0
    end

    def calculate_average_status_changes(requests)
      return 0 if requests.empty?
      
      total_changes = requests.sum do |request|
        AuditLog.where(
          resource_type: 'FlightRequest',
          resource_id: request.id,
          action_type: 'status_change'
        ).count
      end

      (total_changes.to_f / requests.count).round(2)
    end

    def count_requests_with_rework(requests)
      # Count requests that moved backwards in status
      requests.select do |request|
        status_changes = AuditLog.where(
          resource_type: 'FlightRequest',
          resource_id: request.id,
          action_type: 'status_change'
        ).order(:created_at)

        # Check for status reversals (simplified)
        status_changes.count > 3
      end.count
    end

    def extract_failure_reasons(failed_requests)
      reasons = failed_requests.map do |log|
        log.metadata&.dig('failure_reason') || 'Unknown'
      end.compact

      reasons.group_by(&:itself).transform_values(&:count)
    end

    def detect_unusual_access_times(start_date)
      off_hours_count = AuditLog.where(created_at: start_date..Time.current)
                               .where("EXTRACT(hour FROM created_at) < 6 OR EXTRACT(hour FROM created_at) > 22")
                               .count

      {
        off_hours_activity_count: off_hours_count,
        percentage_of_total: off_hours_count > 0 ? 
          ((off_hours_count.to_f / AuditLog.where(created_at: start_date..Time.current).count) * 100).round(2) : 0
      }
    end

    def detect_multiple_location_access(start_date)
      users_with_multiple_ips = AuditLog.joins(:user)
                                       .where(created_at: start_date..Time.current)
                                       .where.not(ip_address: nil)
                                       .group('users.id')
                                       .having('COUNT(DISTINCT ip_address) > ?', 3)
                                       .count

      users_with_multiple_ips.count
    end

    def detect_rapid_successive_attempts(start_date)
      # Detect users with more than 10 actions in a 5-minute window
      rapid_attempts = AuditLog.joins(:user)
                              .where(created_at: start_date..Time.current)
                              .group('users.id')
                              .group_by_minute(:created_at, time_zone: 'UTC')
                              .having('COUNT(*) > ?', 10)
                              .count

      rapid_attempts.count
    end

    # Compliance Helpers
    def audit_log_completeness(start_date, end_date)
      expected_logs = estimate_expected_log_count(start_date, end_date)
      actual_logs = AuditLog.where(created_at: start_date..end_date).count
      
      {
        expected_logs: expected_logs,
        actual_logs: actual_logs,
        completeness_percentage: expected_logs > 0 ? 
          ((actual_logs.to_f / expected_logs) * 100).round(2) : 100
      }
    end

    def user_access_compliance(start_date, end_date)
      {
        users_requiring_review: users_requiring_access_review(start_date, end_date),
        privileged_access_usage: privileged_access_analysis(start_date, end_date),
        access_violations: detect_access_violations(start_date, end_date)
      }
    end

    def data_retention_compliance(start_date, end_date)
      old_logs = AuditLog.where(created_at: ...1.year.ago)
      
      {
        logs_requiring_archival: old_logs.count,
        retention_policy_compliance: old_logs.count < 1000 ? 'compliant' : 'requires_attention'
      }
    end

    def security_incidents_summary(start_date, end_date)
      {
        total_incidents: 0, # Placeholder - would integrate with incident tracking
        resolved_incidents: 0,
        open_incidents: 0,
        incident_categories: {}
      }
    end

    def generate_compliance_recommendations(start_date, end_date)
      recommendations = []
      
      # Analyze audit log completeness
      completeness = audit_log_completeness(start_date, end_date)
      if completeness[:completeness_percentage] < 95
        recommendations << "Audit log completeness is below 95%. Investigate potential logging gaps."
      end

      # Check for old logs
      old_logs_count = AuditLog.where(created_at: ...1.year.ago).count
      if old_logs_count > 1000
        recommendations << "Consider archiving audit logs older than 1 year for data retention compliance."
      end

      # Security recommendations
      if security_events_count(7.days.ago) > 50
        recommendations << "High number of security events detected. Review and strengthen security measures."
      end

      recommendations.empty? ? ["No compliance issues detected."] : recommendations
    end

    def estimate_expected_log_count(start_date, end_date)
      # Estimate based on average daily activity
      days = (end_date - start_date).to_i
      recent_daily_average = AuditLog.where(created_at: 7.days.ago..Time.current).count / 7.0
      
      (days * recent_daily_average).to_i
    end

    def users_requiring_access_review(start_date, end_date)
      # Users with no activity in the review period
      inactive_users = User.left_joins(:audit_logs)
                          .where(audit_logs: { created_at: start_date..end_date })
                          .where(audit_logs: { id: nil })
                          .count

      inactive_users
    end

    def privileged_access_usage(start_date, end_date)
      privileged_users = User.where(role: ['operations_admin', 'management', 'super_admin'])
      
      privileged_users.map do |user|
        activity_count = AuditLog.where(
          user: user,
          created_at: start_date..end_date
        ).count

        {
          user_id: user.id,
          email: user.email,
          role: user.role,
          activity_count: activity_count
        }
      end
    end

    def detect_access_violations(start_date, end_date)
      # Placeholder for access violation detection
      # Would implement based on specific access control rules
      []
    end
  end
end
