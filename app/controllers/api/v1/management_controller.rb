class Api::V1::ManagementController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_management_access

  # GET /api/v1/management/dashboard
  def dashboard
    dashboard_data = ManagementDashboardService.new.generate_dashboard_data(
      date_range: params[:date_range],
      filters: dashboard_filters
    )

    render json: dashboard_data
  end

  # GET /api/v1/management/reports/requests
  def reports
    report_data = ManagementReportingService.new.generate_requests_report(
      start_date: params[:start_date],
      end_date: params[:end_date],
      group_by: params[:group_by],
      filters: report_filters,
      format: params[:format] || "json"
    )

    case params[:format]&.downcase
    when "csv"
      send_data report_data[:csv_data],
                filename: "flight_requests_report_#{Date.current.strftime('%Y%m%d')}.csv",
                type: "text/csv"
    when "pdf"
      send_data report_data[:pdf_data],
                filename: "flight_requests_report_#{Date.current.strftime('%Y%m%d')}.pdf",
                type: "application/pdf"
    else
      render json: report_data
    end
  end

  private

  def authorize_management_access
    unless current_user.role.in?(%w[management super_admin])
      render json: { error: "Access denied. Management privileges required." },
             status: :forbidden
    end
  end

  def dashboard_filters
    {
      status: params[:status],
      vip_profile_id: params[:vip_profile_id],
      source_user_id: params[:source_user_id]
    }.compact
  end

  def report_filters
    {
      status: params[:status],
      vip_profile_id: params[:vip_profile_id],
      source_user_id: params[:source_user_id],
      priority: params[:priority],
      operations_staff_id: params[:operations_staff_id]
    }.compact
  end
end
