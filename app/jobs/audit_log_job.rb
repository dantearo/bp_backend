class AuditLogJob < ApplicationJob
  queue_as :audit_logs

  def perform(request_data:, response_data:, duration:, user_id: nil)
    AuditLog.create!(
      user_id: user_id,
      action_type: determine_action_type(request_data[:method], request_data[:path]),
      resource_type: extract_resource_type(request_data[:path]),
      resource_id: extract_resource_id(request_data[:path], request_data[:params]),
      ip_address: request_data[:ip_address],
      user_agent: request_data[:user_agent],
      metadata: build_metadata(request_data, response_data, duration)
    )
  rescue => e
    Rails.logger.error "Failed to create audit log: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def determine_action_type(method, path)
    case method.upcase
    when 'POST'
      'create'
    when 'GET'
      'read'
    when 'PUT', 'PATCH'
      'update'
    when 'DELETE'
      'delete'
    else
      'read'
    end
  end

  def extract_resource_type(path)
    # Extract resource type from API path
    # Examples: /api/v1/flight_requests -> FlightRequest
    #          /api/v1/vip_profiles -> VipProfile
    
    if match = path.match(/\/api\/v\d+\/([^\/\?]+)/)
      resource_name = match[1]
      resource_name.singularize.camelize
    else
      'System'
    end
  end

  def extract_resource_id(path, params)
    # Try to extract ID from path first
    if match = path.match(/\/(\d+)(?:\/|$|\?)/)
      match[1].to_i
    elsif params.present? && params['id'].present?
      params['id'].to_i
    end
  end

  def build_metadata(request_data, response_data, duration)
    {
      request: {
        method: request_data[:method],
        path: request_data[:path],
        query_string: request_data[:query_string],
        content_type: request_data[:content_type],
        referer: request_data[:referer],
        params: request_data[:params],
        headers: request_data[:headers]
      },
      response: {
        status: response_data[:status],
        content_type: response_data[:content_type],
        content_length: response_data[:content_length]
      },
      performance: {
        duration_ms: duration
      },
      timestamp: Time.current.iso8601
    }
  end
end
