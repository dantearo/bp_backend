require "test_helper"

class Api::V1::ManagementControllerTest < ActionDispatch::IntegrationTest
  def setup
    @management_user = users(:management_user)
    @regular_user = users(:regular_user)
    @flight_request = flight_requests(:pending_request)
  end

  test "should get dashboard with management role" do
    sign_in @management_user
    get api_v1_management_dashboard_path
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('kpis')
    assert json_response.key?('request_status_summary')
    assert json_response.key?('user_activity_overview')
    assert json_response.key?('system_health_metrics')
  end

  test "should deny dashboard access to regular user" do
    sign_in @regular_user
    get api_v1_management_dashboard_path
    assert_response :forbidden
    
    json_response = JSON.parse(response.body)
    assert_equal "Access denied. Management privileges required.", json_response['error']
  end

  test "should get reports with management role" do
    sign_in @management_user
    get api_v1_management_reports_requests_path
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('report_metadata')
    assert json_response.key?('summary_statistics')
    assert json_response.key?('grouped_data')
  end

  test "should get reports with date filters" do
    sign_in @management_user
    get api_v1_management_reports_requests_path, params: {
      start_date: 1.week.ago.to_date,
      end_date: Date.current,
      group_by: 'status'
    }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['report_metadata']['period']['start_date']
    assert json_response['report_metadata']['period']['end_date']
  end

  test "should get reports with filters" do
    sign_in @management_user
    get api_v1_management_reports_requests_path, params: {
      status: 'sent',
      priority: 'high'
    }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal({ 'status' => 'sent', 'priority' => 'high' }, 
                 json_response['report_metadata']['filters_applied'])
  end

  test "should export CSV report" do
    sign_in @management_user
    get api_v1_management_reports_requests_path, params: { format: 'csv' }
    assert_response :success
    assert_equal 'text/csv', response.content_type
    assert response.headers['Content-Disposition'].include?('flight_requests_report')
  end

  test "should handle PDF export request" do
    sign_in @management_user
    get api_v1_management_reports_requests_path, params: { format: 'pdf' }
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  test "should deny reports access to regular user" do
    sign_in @regular_user
    get api_v1_management_reports_requests_path
    assert_response :forbidden
  end

  test "dashboard should include KPIs" do
    sign_in @management_user
    get api_v1_management_dashboard_path
    assert_response :success
    
    json_response = JSON.parse(response.body)
    kpis = json_response['kpis']
    
    assert kpis.key?('total_requests')
    assert kpis.key?('active_requests')
    assert kpis.key?('completed_requests')
    assert kpis.key?('completion_rate')
    assert kpis.key?('average_processing_time')
  end

  test "dashboard should include request status summary" do
    sign_in @management_user
    get api_v1_management_dashboard_path
    assert_response :success
    
    json_response = JSON.parse(response.body)
    status_summary = json_response['request_status_summary']
    
    assert status_summary.key?('status_distribution')
    assert status_summary.key?('total_requests')
    assert status_summary.key?('status_percentages')
  end

  test "dashboard should include user activity overview" do
    sign_in @management_user
    get api_v1_management_dashboard_path
    assert_response :success
    
    json_response = JSON.parse(response.body)
    user_activity = json_response['user_activity_overview']
    
    assert user_activity.key?('active_users_count')
    assert user_activity.key?('top_request_sources')
    assert user_activity.key?('operations_staff_workload')
  end

  test "dashboard should handle date range parameter" do
    sign_in @management_user
    get api_v1_management_dashboard_path, params: { date_range: 'week' }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('period')
    assert_equal 7, json_response['period']['days']
  end

  test "reports should include VIP activity report" do
    sign_in @management_user
    get api_v1_management_reports_requests_path
    assert_response :success
    
    json_response = JSON.parse(response.body)
    vip_report = json_response['vip_activity_report']
    
    assert vip_report.key?('total_vip_requests')
    assert vip_report.key?('vip_breakdown')
    assert vip_report.key?('vip_completion_rates')
  end

  test "reports should include operations efficiency report" do
    sign_in @management_user
    get api_v1_management_reports_requests_path
    assert_response :success
    
    json_response = JSON.parse(response.body)
    ops_report = json_response['operations_efficiency_report']
    
    assert ops_report.key?('staff_workload')
    assert ops_report.key?('processing_time_by_staff')
    assert ops_report.key?('bottleneck_analysis')
  end

  private

  def sign_in(user)
    # Placeholder for authentication - replace with actual auth method
    # This assumes you have a way to authenticate users in tests
    session[:user_id] = user.id if user
  end
end
