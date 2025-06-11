class ApplicationController < ActionController::API
  # Error handling
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ActionController::ParameterMissing, with: :parameter_missing

  private

  def record_not_found(exception)
    render json: { error: "Record not found" }, status: :not_found
  end

  def record_invalid(exception)
    render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
  end

  def parameter_missing(exception)
    render json: { error: "Missing parameter: #{exception.param}" }, status: :bad_request
  end

  # Authentication placeholder methods
  def authenticate_user!
    # Implementation depends on your authentication strategy
    # This could be JWT, session-based, or API key authentication
    render json: { error: "Authentication required" }, status: :unauthorized unless current_user
  end

  def current_user
    # Implementation depends on your authentication strategy
    @current_user ||= authenticate_request
  end

  def authenticate_request
    # Placeholder for authentication logic
    # This should decode JWT token, verify API key, or check session
    nil
  end
end
