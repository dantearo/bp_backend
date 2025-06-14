require "test_helper"

class AuthenticationAuditServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      uae_pass_id: "UAETEST#{SecureRandom.hex(6)}",
      first_name: "Test",
      last_name: "User",
      role: "source_of_request",
      status: "active"
    )
  end

  test "should log successful login attempt" do
    assert_difference 'AuditLog.count', 1 do
      AuthenticationAuditService.log_login_attempt(
        user: @user,
        email: @user.email,
        ip_address: "192.168.1.1",
        user_agent: "Test Browser",
        success: true
      )
    end

    log = AuditLog.last
    assert_equal @user, log.user
    assert_equal "login", log.action_type
    assert_equal "Authentication", log.resource_type
    assert_equal "login_success", log.metadata["event_type"]
  end

  test "should log failed login attempt" do
    assert_difference 'AuditLog.count', 1 do
      AuthenticationAuditService.log_login_attempt(
        user: nil,
        email: "wrong@email.com",
        ip_address: "192.168.1.1",
        user_agent: "Test Browser",
        success: false,
        failure_reason: "Invalid credentials"
      )
    end

    log = AuditLog.last
    assert_nil log.user
    assert_equal "login", log.action_type
    assert_equal "Authentication", log.resource_type
    assert_equal "login_failure", log.metadata["event_type"]
    assert_equal "Invalid credentials", log.metadata["failure_reason"]
  end

  test "should log logout event" do
    assert_difference 'AuditLog.count', 1 do
      AuthenticationAuditService.log_logout(
        user: @user,
        ip_address: "192.168.1.1",
        user_agent: "Test Browser",
        session_duration: 60
      )
    end

    log = AuditLog.last
    assert_equal @user, log.user
    assert_equal "logout", log.action_type
    assert_equal "Authentication", log.resource_type
    assert_equal "logout", log.metadata["event_type"]
    assert_equal 60, log.metadata["session_duration_minutes"]
  end

  test "should log UAE Pass events" do
    assert_difference 'AuditLog.count', 1 do
      AuthenticationAuditService.log_uae_pass_event(
        user: @user,
        event_type: "uae_pass_verification_success",
        ip_address: "192.168.1.1",
        user_agent: "Test Browser",
        metadata: { uae_pass_id: "12345" }
      )
    end

    log = AuditLog.last
    assert_equal @user, log.user
    assert_equal "login", log.action_type
    assert_equal "UAE_Pass", log.resource_type
    assert_equal "uae_pass_verification_success", log.metadata["event_type"]
    assert_equal({ "uae_pass_id" => "12345" }, log.metadata["uae_pass_data"])
  end

  test "should detect suspicious activity" do
    # Create multiple failed login attempts from same IP (need more than 5 to trigger suspicion)
    6.times do
      AuthenticationAuditService.log_login_attempt(
        user: nil,
        email: "test@email.com",
        ip_address: "192.168.1.100",
        user_agent: "Test Browser",
        success: false,
        failure_reason: "Invalid credentials"
      )
    end

    suspicious_ips = AuthenticationAuditService.suspicious_ip_addresses(1)
    assert suspicious_ips.has_key?("192.168.1.100"), "Expected IP 192.168.1.100 to be in suspicious IPs: #{suspicious_ips}"
    assert suspicious_ips["192.168.1.100"] >= 6, "Expected at least 6 failures for IP 192.168.1.100, got #{suspicious_ips["192.168.1.100"]}"
  end

  test "should provide user activity summary" do
    # Create some login/logout events
    AuthenticationAuditService.log_login_attempt(
      user: @user,
      email: @user.email,
      ip_address: "192.168.1.1",
      success: true
    )
    
    AuthenticationAuditService.log_logout(
      user: @user,
      ip_address: "192.168.1.1"
    )

    summary = AuthenticationAuditService.user_activity_summary(user: @user)
    
    assert_equal 1, summary[:total_logins]
    assert_equal 1, summary[:total_logouts]
    assert_equal 1, summary[:unique_ip_addresses]
    assert summary.has_key?(:login_patterns)
  end
end
