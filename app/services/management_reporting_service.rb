class ManagementReportingService
  require "csv"

  def initialize
    @default_start_date = 30.days.ago.beginning_of_day
    @default_end_date = Time.current.end_of_day
  end

  def generate_requests_report(start_date: nil, end_date: nil, group_by: nil, filters: {}, format: "json")
    @start_date = parse_date(start_date) || @default_start_date
    @end_date = parse_date(end_date) || @default_end_date
    @group_by = group_by || "status"
    @filters = filters.compact
    @format = format.downcase

    case @format
    when "csv"
      { csv_data: generate_csv_report }
    when "pdf"
      { pdf_data: generate_pdf_report }
    else
      generate_json_report
    end
  end

  private

  def generate_json_report
    flight_requests = filtered_flight_requests

    {
      report_metadata: {
        generated_at: Time.current,
        period: {
          start_date: @start_date,
          end_date: @end_date,
          days: (@end_date - @start_date).to_i / 1.day
        },
        total_requests: flight_requests.count,
        filters_applied: @filters
      },
      summary_statistics: generate_summary_statistics(flight_requests),
      grouped_data: generate_grouped_data(flight_requests),
      vip_activity_report: generate_vip_activity_report(flight_requests),
      operations_efficiency_report: generate_operations_efficiency_report(flight_requests),
      detailed_requests: generate_detailed_requests(flight_requests)
    }
  end

  def generate_summary_statistics(requests)
    {
      total_requests: requests.count,
      status_breakdown: requests.group(:status).count,
      priority_breakdown: requests.group(:priority).count,
      completion_metrics: {
        completed_count: requests.where(status: "completed").count,
        canceled_count: requests.where(status: %w[canceled unable]).count,
        active_count: requests.where(status: %w[sent received under_review processing]).count,
        completion_rate: calculate_completion_rate(requests)
      },
      time_metrics: {
        average_processing_time_hours: calculate_average_processing_time(requests),
        fastest_completion_hours: calculate_fastest_completion(requests),
        slowest_completion_hours: calculate_slowest_completion(requests)
      }
    }
  end

  def generate_grouped_data(requests)
    case @group_by
    when "date"
      requests.group_by_day(:created_at, time_zone: Time.zone)
              .count
              .transform_keys(&:to_date)
    when "week"
      requests.group_by_week(:created_at, time_zone: Time.zone)
              .count
              .transform_keys(&:to_date)
    when "month"
      requests.group_by_month(:created_at, time_zone: Time.zone)
              .count
              .transform_keys(&:to_date)
    when "vip"
      requests.joins(:vip_profile)
              .group("vip_profiles.codename")
              .count
    when "user"
      requests.joins(:source_of_request_user)
              .group("users.name")
              .count
    when "priority"
      requests.group(:priority).count
    else # default to status
      requests.group(:status).count
    end
  end

  def generate_vip_activity_report(requests)
    vip_requests = requests.joins(:vip_profile)

    {
      total_vip_requests: vip_requests.count,
      vip_breakdown: vip_requests.joins(:vip_profile)
                                .group("vip_profiles.codename")
                                .count
                                .sort_by { |_, count| -count }
                                .first(20)
                                .to_h,
      vip_completion_rates: calculate_vip_completion_rates(vip_requests),
      high_activity_vips: identify_high_activity_vips(vip_requests)
    }
  end

  def generate_operations_efficiency_report(requests)
    {
      staff_workload: calculate_staff_workload(requests),
      processing_time_by_staff: calculate_processing_time_by_staff(requests),
      status_transition_metrics: calculate_status_transition_metrics(requests),
      bottleneck_analysis: identify_bottlenecks(requests)
    }
  end

  def generate_detailed_requests(requests)
    requests.includes(:vip_profile, :source_of_request_user, :operations_staff_user, :flight_request_legs)
            .order(:created_at)
            .limit(100) # Limit for performance
            .map do |request|
      {
        id: request.id,
        request_number: request.request_number,
        status: request.status,
        priority: request.priority,
        vip_codename: request.vip_profile&.codename,
        source_user: request.source_of_request_user&.name,
        operations_staff: request.operations_staff_user&.name,
        created_at: request.created_at,
        processed_at: request.processed_at,
        processing_time_hours: request.processed_at ?
          ((request.processed_at - request.created_at) / 3600).round(2) : nil,
        legs_count: request.flight_request_legs.count,
        has_passenger_list: request.passenger_list_filename.present?,
        has_flight_brief: request.flight_brief_filename.present?
      }
    end
  end

  def generate_csv_report
    requests = filtered_flight_requests.includes(:vip_profile, :source_of_request_user, :operations_staff_user)

    CSV.generate(headers: true) do |csv|
      csv << [
        "Request Number", "Status", "Priority", "VIP Codename", "Source User",
        "Operations Staff", "Created At", "Processed At", "Processing Time (Hours)",
        "Legs Count", "Has Passenger List", "Has Flight Brief"
      ]

      requests.find_each do |request|
        csv << [
          request.request_number,
          request.status.humanize,
          request.priority.to_s.humanize,
          request.vip_profile&.codename || "N/A",
          request.source_of_request_user&.name || "Unknown",
          request.operations_staff_user&.name || "Unassigned",
          request.created_at.strftime("%Y-%m-%d %H:%M:%S"),
          request.processed_at&.strftime("%Y-%m-%d %H:%M:%S") || "N/A",
          request.processed_at ?
            ((request.processed_at - request.created_at) / 3600).round(2) : "N/A",
          request.flight_request_legs.count,
          request.passenger_list_filename.present? ? "Yes" : "No",
          request.flight_brief_filename.present? ? "Yes" : "No"
        ]
      end
    end
  end

  def generate_pdf_report
    # Placeholder for PDF generation
    # In a real implementation, you'd use a gem like Prawn or wicked_pdf
    "PDF generation not implemented - would require additional gems like Prawn"
  end

  def filtered_flight_requests
    scope = FlightRequest.where(created_at: @start_date..@end_date)

    scope = scope.where(status: @filters[:status]) if @filters[:status]
    scope = scope.where(vip_profile_id: @filters[:vip_profile_id]) if @filters[:vip_profile_id]
    scope = scope.where(source_of_request_user_id: @filters[:source_user_id]) if @filters[:source_user_id]
    scope = scope.where(priority: @filters[:priority]) if @filters[:priority]
    scope = scope.where(operations_staff_user_id: @filters[:operations_staff_id]) if @filters[:operations_staff_id]

    scope
  end

  def calculate_completion_rate(requests)
    return 0 if requests.empty?

    completed_count = requests.where(status: "completed").count
    (completed_count.to_f / requests.count * 100).round(2)
  end

  def calculate_average_processing_time(requests)
    completed_requests = requests.where(status: "completed")
                               .where.not(processed_at: nil)

    return 0 if completed_requests.empty?

    total_time = completed_requests.sum do |request|
      (request.processed_at - request.created_at).to_i
    end

    (total_time.to_f / completed_requests.count / 3600).round(2)
  end

  def calculate_fastest_completion(requests)
    completed_requests = requests.where(status: "completed")
                               .where.not(processed_at: nil)

    return 0 if completed_requests.empty?

    fastest = completed_requests.minimum("EXTRACT(EPOCH FROM (processed_at - created_at))")
    (fastest / 3600).round(2)
  end

  def calculate_slowest_completion(requests)
    completed_requests = requests.where(status: "completed")
                               .where.not(processed_at: nil)

    return 0 if completed_requests.empty?

    slowest = completed_requests.maximum("EXTRACT(EPOCH FROM (processed_at - created_at))")
    (slowest / 3600).round(2)
  end

  def calculate_vip_completion_rates(vip_requests)
    vip_requests.joins(:vip_profile)
               .group("vip_profiles.codename")
               .group(:status)
               .count
               .each_with_object({}) do |((vip_name, status), count), hash|
      hash[vip_name] ||= { total: 0, completed: 0 }
      hash[vip_name][:total] += count
      hash[vip_name][:completed] += count if status == "completed"
    end
               .transform_values do |stats|
      completion_rate = stats[:total] > 0 ?
        (stats[:completed].to_f / stats[:total] * 100).round(2) : 0
      stats.merge(completion_rate: completion_rate)
    end
  end

  def identify_high_activity_vips(vip_requests)
    vip_requests.joins(:vip_profile)
               .group("vip_profiles.codename")
               .count
               .select { |_, count| count >= 5 }
               .sort_by { |_, count| -count }
               .to_h
  end

  def calculate_staff_workload(requests)
    requests.joins(:operations_staff_user)
           .group("users.name")
           .count
           .sort_by { |_, count| -count }
           .to_h
  end

  def calculate_processing_time_by_staff(requests)
    requests.where(status: "completed")
           .where.not(processed_at: nil)
           .joins(:operations_staff_user)
           .group("users.name")
           .average("EXTRACT(EPOCH FROM (processed_at - created_at)) / 3600")
           .transform_values { |avg| avg&.round(2) || 0 }
  end

  def calculate_status_transition_metrics(requests)
    # This would require audit log analysis
    # Placeholder for now
    {
      average_time_to_receive: "Requires audit log analysis",
      average_time_to_review: "Requires audit log analysis",
      average_time_to_process: "Requires audit log analysis"
    }
  end

  def identify_bottlenecks(requests)
    bottlenecks = []

    # Check for requests stuck in specific statuses
    old_received = requests.where(status: "received")
                          .where("created_at < ?", 24.hours.ago)
                          .count

    if old_received > 0
      bottlenecks << {
        type: "status_bottleneck",
        status: "received",
        count: old_received,
        message: "#{old_received} requests stuck in 'received' status for > 24 hours"
      }
    end

    old_review = requests.where(status: "under_review")
                        .where("created_at < ?", 48.hours.ago)
                        .count

    if old_review > 0
      bottlenecks << {
        type: "status_bottleneck",
        status: "under_review",
        count: old_review,
        message: "#{old_review} requests stuck in 'under_review' status for > 48 hours"
      }
    end

    bottlenecks
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    Date.parse(date_string).beginning_of_day
  rescue ArgumentError
    nil
  end
end
