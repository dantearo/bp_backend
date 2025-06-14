class AuthenticationAuditService
  class << self
    def log_login_attempt(user: nil, email: nil, ip_address: nil, user_agent: nil, success: true, failure_reason: nil)
      AuditLog.create!(
        user: user,
        action_type: 'login',
        resource_type: 'Authentication',
        ip_address: ip_address,
        user_agent: user_agent,
        metadata: {
          event_type: success ? 'login_success' : 'login_failure',
          email: email,
          failure_reason: failure_reason,
          timestamp: Time.current.iso8601,
          security_context: {
            suspicious_activity: detect_suspicious_activity(ip_address, email),
            geographic_info: extract_geographic_info(ip_address),
            device_fingerprint: generate_device_fingerprint(user_agent)
          }
        }
      )
    end

    def log_logout(user:, ip_address: nil, user_agent: nil, session_duration: nil)
      AuditLog.create!(
        user: user,
        action_type: 'logout',
        resource_type: 'Authentication',
        ip_address: ip_address,
        user_agent: user_agent,
        metadata: {
          event_type: 'logout',
          session_duration_minutes: session_duration,
          timestamp: Time.current.iso8601
        }
      )
    end

    def log_uae_pass_event(user: nil, event_type:, ip_address: nil, user_agent: nil, metadata: {})
      AuditLog.create!(
        user: user,
        action_type: 'login',
        resource_type: 'UAE_Pass',
        ip_address: ip_address,
        user_agent: user_agent,
        metadata: {
          event_type: event_type,
          uae_pass_data: metadata,
          timestamp: Time.current.iso8601,
          security_context: {
            suspicious_activity: detect_suspicious_activity(ip_address, metadata[:email]),
            geographic_info: extract_geographic_info(ip_address)
          }
        }
      )
    end

    def log_session_event(user:, event_type:, ip_address: nil, user_agent: nil, details: {})
      AuditLog.create!(
        user: user,
        action_type: determine_session_action(event_type),
        resource_type: 'Session',
        ip_address: ip_address,
        user_agent: user_agent,
        metadata: {
          event_type: event_type,
          session_details: details,
          timestamp: Time.current.iso8601
        }
      )
    end

    def log_password_reset(email:, ip_address: nil, user_agent: nil, success: true)
      AuditLog.create!(
        user: nil,
        action_type: 'update',
        resource_type: 'Password',
        ip_address: ip_address,
        user_agent: user_agent,
        metadata: {
          event_type: success ? 'password_reset_success' : 'password_reset_failure',
          email: email,
          timestamp: Time.current.iso8601
        }
      )
    end

    def log_account_lockout(user: nil, email: nil, ip_address: nil, reason:)
      AuditLog.create!(
        user: user,
        action_type: 'update',
        resource_type: 'Account',
        ip_address: ip_address,
        metadata: {
          event_type: 'account_lockout',
          email: email,
          lockout_reason: reason,
          timestamp: Time.current.iso8601
        }
      )
    end

    # Analytics methods for authentication patterns
    def recent_login_failures(hours = 24)
      AuditLog.where(
        action_type: 'login',
        created_at: hours.hours.ago..Time.current
      ).where(
        "metadata ->> 'event_type' = ?", 'login_failure'
      )
    end

    def suspicious_ip_addresses(hours = 24)
      recent_login_failures(hours)
        .group(:ip_address)
        .having('COUNT(*) > ?', 5)
        .count
    end

    def user_activity_summary(user:, days: 30)
      logs = AuditLog.where(
        user: user,
        created_at: days.days.ago..Time.current
      ).where(action_type: ['login', 'logout'])

      {
        total_logins: logs.where(action_type: 'login').count,
        total_logouts: logs.where(action_type: 'logout').count,
        unique_ip_addresses: logs.distinct.count(:ip_address),
        last_login: logs.where(action_type: 'login').order(:created_at).last&.created_at,
        login_patterns: analyze_login_patterns(logs)
      }
    end

    private

    def determine_session_action(event_type)
      case event_type
      when 'session_created', 'session_renewed'
        'create'
      when 'session_expired', 'session_terminated'
        'delete'
      else
        'update'
      end
    end

    def detect_suspicious_activity(ip_address, email)
      return false unless ip_address && email

      recent_failures = AuditLog.where(
        ip_address: ip_address,
        created_at: 1.hour.ago..Time.current
      ).where(
        "metadata ->> 'event_type' = ?", 'login_failure'
      ).count

      recent_failures > 3
    end

    def extract_geographic_info(ip_address)
      return nil unless ip_address

      # Placeholder for IP geolocation service
      # In production, integrate with MaxMind GeoIP2 or similar
      {
        ip: ip_address,
        country: 'Unknown',
        city: 'Unknown',
        note: 'Geographic resolution not implemented'
      }
    end

    def generate_device_fingerprint(user_agent)
      return nil unless user_agent

      Digest::SHA256.hexdigest(user_agent)[0..16]
    end

    def analyze_login_patterns(logs)
      login_logs = logs.where(action_type: 'login')
      
      {
        most_common_hours: login_logs.group_by { |log| log.created_at.hour }.transform_values(&:count),
        device_diversity: login_logs.map { |log| generate_device_fingerprint(log.user_agent) }.uniq.count,
        ip_diversity: login_logs.distinct.count(:ip_address)
      }
    end
  end
end
