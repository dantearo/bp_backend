class Api::V1::AdminController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  # POST /api/v1/admin/users - Create new user
  def create_user
    user = User.new(user_params)
    
    if user.save
      AuditLog.create(
        auditable: user,
        user: current_user,
        action: 'user_created',
        changes: user.attributes,
        metadata: { timestamp: Time.current }
      )
      render json: { message: 'User created successfully', user: user_response(user) }, status: :created
    else
      render json: { errors: user.errors }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/admin/users - List all users
  def list_users
    users = User.all
    
    # Apply filters
    users = users.where(role: params[:role]) if params[:role].present?
    users = users.where(status: params[:status]) if params[:status].present?
    users = users.where('email ILIKE ?', "%#{params[:search]}%") if params[:search].present?

    users = users.page(params[:page]).per(params[:per_page] || 20)

    render json: {
      users: users.map { |user| user_response(user) },
      pagination: {
        current_page: users.current_page,
        total_pages: users.total_pages,
        total_count: users.total_count
      }
    }, status: :ok
  end

  # PUT /api/v1/admin/users/:id - Update user
  def update_user
    user = User.find(params[:id])
    old_attributes = user.attributes.dup
    
    if user.update(user_update_params)
      changes = {}
      user_update_params.keys.each do |key|
        if old_attributes[key] != user.attributes[key]
          changes[key] = [old_attributes[key], user.attributes[key]]
        end
      end

      if changes.any?
        AuditLog.create(
          auditable: user,
          user: current_user,
          action: 'user_updated',
          changes: changes,
          metadata: { timestamp: Time.current }
        )
      end

      render json: { message: 'User updated successfully', user: user_response(user) }, status: :ok
    else
      render json: { errors: user.errors }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  # DELETE /api/v1/admin/users/:id - Soft delete/freeze user
  def delete_user
    user = User.find(params[:id])
    
    if user.update(status: 'frozen', deleted_at: Time.current)
      AuditLog.create(
        auditable: user,
        user: current_user,
        action: 'user_deleted',
        changes: { status: [user.status_was, 'frozen'], deleted_at: [nil, Time.current] },
        metadata: { timestamp: Time.current }
      )
      render json: { message: 'User frozen successfully' }, status: :ok
    else
      render json: { errors: user.errors }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  # POST /api/v1/admin/vip_profiles - Create VIP Profile
  def create_vip_profile
    vip_profile = VipProfile.new(vip_profile_params)
    vip_profile.generate_codename if vip_profile.codename.blank?
    
    if vip_profile.save
      AuditLog.create(
        auditable: vip_profile,
        user: current_user,
        action: 'vip_profile_created',
        changes: vip_profile.attributes,
        metadata: { timestamp: Time.current }
      )
      render json: { message: 'VIP Profile created successfully', vip_profile: vip_profile_response(vip_profile) }, status: :created
    else
      render json: { errors: vip_profile.errors }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/admin/vip_profiles - List all VIP profiles
  def list_vip_profiles
    vip_profiles = VipProfile.all
    
    # Apply filters
    vip_profiles = vip_profiles.where('name ILIKE ? OR codename ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    vip_profiles = vip_profiles.where(security_clearance: params[:security_clearance]) if params[:security_clearance].present?

    vip_profiles = vip_profiles.page(params[:page]).per(params[:per_page] || 20)

    render json: {
      vip_profiles: vip_profiles.map { |profile| vip_profile_response(profile) },
      pagination: {
        current_page: vip_profiles.current_page,
        total_pages: vip_profiles.total_pages,
        total_count: vip_profiles.total_count
      }
    }, status: :ok
  end

  # PUT /api/v1/admin/vip_profiles/:id - Update VIP profile
  def update_vip_profile
    vip_profile = VipProfile.find(params[:id])
    old_attributes = vip_profile.attributes.dup
    
    if vip_profile.update(vip_profile_update_params)
      changes = {}
      vip_profile_update_params.keys.each do |key|
        if old_attributes[key] != vip_profile.attributes[key]
          changes[key] = [old_attributes[key], vip_profile.attributes[key]]
        end
      end

      if changes.any?
        AuditLog.create(
          auditable: vip_profile,
          user: current_user,
          action: 'vip_profile_updated',
          changes: changes,
          metadata: { timestamp: Time.current }
        )
      end

      render json: { message: 'VIP Profile updated successfully', vip_profile: vip_profile_response(vip_profile) }, status: :ok
    else
      render json: { errors: vip_profile.errors }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'VIP Profile not found' }, status: :not_found
  end

  # DELETE /api/v1/admin/vip_profiles/:id - Soft delete VIP profile
  def delete_vip_profile
    vip_profile = VipProfile.find(params[:id])
    
    if vip_profile.update(deleted_at: Time.current)
      AuditLog.create(
        auditable: vip_profile,
        user: current_user,
        action: 'vip_profile_deleted',
        changes: { deleted_at: [nil, Time.current] },
        metadata: { timestamp: Time.current }
      )
      render json: { message: 'VIP Profile deleted successfully' }, status: :ok
    else
      render json: { errors: vip_profile.errors }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'VIP Profile not found' }, status: :not_found
  end

  # DELETE /api/v1/admin/flight_requests/:id - Admin delete flight request
  def delete_flight_request
    flight_request = FlightRequest.find(params[:id])
    
    if flight_request.update(status: 'deleted', deleted_at: Time.current)
      AuditLog.create(
        auditable: flight_request,
        user: current_user,
        action: 'admin_delete_request',
        changes: { status: [flight_request.status_was, 'deleted'], deleted_at: [nil, Time.current] },
        metadata: { timestamp: Time.current }
      )
      render json: { message: 'Flight request deleted successfully' }, status: :ok
    else
      render json: { errors: flight_request.errors }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Flight request not found' }, status: :not_found
  end

  # PUT /api/v1/admin/flight_requests/:id/finalize - Admin finalize request
  def finalize_flight_request
    flight_request = FlightRequest.find(params[:id])
    
    if flight_request.update(status: 'completed', completed_at: Time.current, finalized_by: current_user.id)
      AuditLog.create(
        auditable: flight_request,
        user: current_user,
        action: 'admin_finalize_request',
        changes: { status: [flight_request.status_was, 'completed'], finalized_by: [nil, current_user.id] },
        metadata: { timestamp: Time.current }
      )
      render json: { message: 'Flight request finalized successfully', flight_request: flight_request }, status: :ok
    else
      render json: { errors: flight_request.errors }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Flight request not found' }, status: :not_found
  end

  private

  def ensure_admin!
    unless ['operations_admin', 'management', 'super_admin'].include?(current_user.role)
      render json: { error: 'Admin access required' }, status: :forbidden
    end
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :role, :status, :first_name, :last_name, :phone_number)
  end

  def user_update_params
    params.require(:user).permit(:email, :role, :status, :first_name, :last_name, :phone_number)
  end

  def vip_profile_params
    params.require(:vip_profile).permit(:name, :codename, :security_clearance, :preferred_aircraft_type, :special_requirements, :preferences)
  end

  def vip_profile_update_params
    params.require(:vip_profile).permit(:name, :codename, :security_clearance, :preferred_aircraft_type, :special_requirements, :preferences)
  end

  def user_response(user)
    {
      id: user.id,
      email: user.email,
      role: user.role,
      status: user.status,
      first_name: user.first_name,
      last_name: user.last_name,
      phone_number: user.phone_number,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  def vip_profile_response(vip_profile)
    response = {
      id: vip_profile.id,
      codename: vip_profile.codename,
      security_clearance: vip_profile.security_clearance,
      preferred_aircraft_type: vip_profile.preferred_aircraft_type,
      special_requirements: vip_profile.special_requirements,
      preferences: vip_profile.preferences,
      created_at: vip_profile.created_at,
      updated_at: vip_profile.updated_at
    }

    # Only show actual name to certain roles
    if ['operations_admin', 'management', 'super_admin'].include?(current_user.role)
      response[:name] = vip_profile.name
    end

    response
  end
end
