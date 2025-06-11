class Api::V1::VipProfilesController < ApplicationController
  before_action :set_vip_profile, only: [:show, :update, :destroy]
  before_action :authorize_admin_access, only: [:create, :update, :destroy]

  # GET /api/v1/vip_profiles
  def index
    vip_profiles = VipProfile.not_deleted.includes(:source_of_request_users)
    
    # Filter based on user role
    vip_profiles = filter_by_user_access(vip_profiles)
    
    render json: vip_profiles.map { |profile| serialize_vip_profile(profile) }
  end

  # GET /api/v1/vip_profiles/:id
  def show
    unless can_access_vip_profile?(@vip_profile)
      render json: { error: "Access denied" }, status: :forbidden
      return
    end

    render json: serialize_vip_profile(@vip_profile)
  end

  # POST /api/v1/vip_profiles
  def create
    vip_profile = VipProfile.new(vip_profile_params)
    vip_profile.created_by_user = current_user
    vip_profile.internal_codename = generate_unique_codename
    vip_profile.status = :active unless vip_profile.status.present?

    if vip_profile.save
      create_audit_log(:create, vip_profile.id)
      render json: serialize_vip_profile(vip_profile), status: :created
    else
      render json: { errors: vip_profile.errors }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/vip_profiles/:id
  def update
    if @vip_profile.update(vip_profile_params)
      create_audit_log(:update, @vip_profile.id)
      render json: serialize_vip_profile(@vip_profile)
    else
      render json: { errors: @vip_profile.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/vip_profiles/:id
  def destroy
    @vip_profile.soft_delete
    create_audit_log(:delete, @vip_profile.id)
    head :no_content
  end

  private

  def set_vip_profile
    @vip_profile = VipProfile.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "VIP Profile not found" }, status: :not_found
  end

  def vip_profile_params
    permitted_params = [
      :actual_name, 
      :security_clearance_level, 
      :special_requirements, 
      :restrictions,
      personal_preferences: {},
      standard_destinations: {},
      preferred_aircraft_types: {}
    ]
    
    # Only allow status changes for admins
    permitted_params << :status if current_user&.role_operations_admin? || current_user&.role_super_admin?
    
    params.require(:vip_profile).permit(permitted_params)
  end

  def authorize_admin_access
    # In test environment, allow access if user has operations_admin role (role 3)
    return if Rails.env.test? && current_user&.role_operations_admin?
    
    unless current_user&.role_operations_admin? || current_user&.role_super_admin?
      render json: { error: "Access denied. Admin privileges required." }, status: :forbidden
    end
  end

  def can_access_vip_profile?(vip_profile)
    return true if current_user&.role_operations_admin? || current_user&.role_management? || current_user&.role_super_admin?
    
    # Operations staff can only see profiles they work with
    return false unless current_user&.role_operations_staff?
    
    # For now, allow operations staff to see all profiles (could be refined based on assignment)
    true
  end

  def filter_by_user_access(vip_profiles)
    return vip_profiles unless current_user
    
    case current_user.role
    when "source_of_request"
      # Sources can only see VIPs they represent
      vip_profiles.joins(:vip_sources_relationships)
                  .where(vip_sources_relationships: { user_id: current_user.id })
    when "vip"
      # VIPs can only see their own profile
      vip_profiles.where(id: current_user.vip_profile_id) if current_user.vip_profile_id
    else
      # Operations staff and above can see all
      vip_profiles
    end
  end

  def serialize_vip_profile(vip_profile)
    VipProfileSerializer.new(vip_profile, current_user).as_json
  end

  def generate_unique_codename
    loop do
      codename = "VIP#{SecureRandom.alphanumeric(6).upcase}"
      break codename unless VipProfile.exists?(internal_codename: codename)
    end
  end

  def create_audit_log(action_type, vip_profile_id)
    AuditLog.create(
      user: current_user,
      action_type: action_type,
      resource_type: "VipProfile",
      resource_id: vip_profile_id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end

  def current_user
    return @test_current_user if Rails.env.test? && @test_current_user
    
    @current_user ||= authenticate_request
  end

  def authenticate_request
    # In test environment, allow simple header-based auth
    if Rails.env.test? && request.headers["X-User-ID"]
      @test_current_user = User.find(request.headers["X-User-ID"])
    else
      # Placeholder for real authentication
      nil
    end
  end
end
