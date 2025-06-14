require 'action_dispatch'

class AuditLoggingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Skip logging for health checks and static assets
    return @app.call(env) if skip_logging?(request)

    start_time = Time.current
    status, headers, response = @app.call(env)
    end_time = Time.current

    # Log the request/response in a background job
    AuditLogJob.perform_later(
      request_data: extract_request_data(request),
      response_data: extract_response_data(status, headers, response),
      duration: ((end_time - start_time) * 1000).round(2),
      user_id: current_user_id(request)
    )

    [status, headers, response]
  rescue => e
    Rails.logger.error "Audit logging error: #{e.message}"
    [status, headers, response]
  end

  private

  def skip_logging?(request)
    skip_paths = [
      '/health',
      '/assets',
      '/favicon.ico',
      '/robots.txt'
    ]
    
    skip_paths.any? { |path| request.path.start_with?(path) } ||
      request.path.match?(/\.(css|js|png|jpg|jpeg|gif|ico|svg)$/)
  end

  def extract_request_data(request)
    {
      method: request.method,
      path: request.path,
      query_string: request.query_string.presence,
      content_type: request.content_type,
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      referer: request.referer,
      params: sanitize_params(request.params),
      headers: sanitize_headers(request.headers)
    }
  end

  def extract_response_data(status, headers, response)
    {
      status: status,
      content_type: headers['Content-Type'],
      content_length: headers['Content-Length']
    }
  end

  def sanitize_params(params)
    sensitive_keys = %w[password password_confirmation token auth_token api_key secret]
    params.except(*sensitive_keys).to_h.deep_transform_values do |value|
      if sensitive_keys.any? { |key| value.to_s.downcase.include?(key) }
        '[FILTERED]'
      else
        value
      end
    end
  end

  def sanitize_headers(headers)
    safe_headers = %w[
      HTTP_ACCEPT HTTP_ACCEPT_ENCODING HTTP_ACCEPT_LANGUAGE
      HTTP_CACHE_CONTROL HTTP_CONNECTION HTTP_HOST
      HTTP_USER_AGENT HTTP_REFERER CONTENT_LENGTH CONTENT_TYPE
    ]
    
    headers.select { |key, _| safe_headers.include?(key) }.to_h
  end

  def current_user_id(request)
    # Extract user ID from session or JWT token
    if request.session[:user_id]
      request.session[:user_id]
    elsif auth_header = request.headers['Authorization']
      # Extract from JWT if using token-based auth
      extract_user_from_token(auth_header)
    end
  end

  def extract_user_from_token(auth_header)
    # Placeholder for JWT token extraction
    # Will be implemented when authentication system is in place
    nil
  end
end
