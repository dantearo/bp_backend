class VipProfileSerializer
  def initialize(vip_profile, current_user)
    @vip_profile = vip_profile
    @current_user = current_user
  end

  def as_json
    base_attributes.merge(role_specific_attributes)
  end

  private

  attr_reader :vip_profile, :current_user

  def base_attributes
    {
      id: vip_profile.id,
      internal_codename: vip_profile.internal_codename,
      status: vip_profile.status,
      created_at: vip_profile.created_at,
      updated_at: vip_profile.updated_at
    }
  end

  def role_specific_attributes
    case access_level
    when :operations_staff
      operations_staff_attributes
    when :operations_admin
      operations_admin_attributes
    when :full_access
      full_access_attributes
    else
      {}
    end
  end

  def access_level
    return :limited unless current_user
    
    return :full_access if current_user.role_management? || current_user.role_super_admin?
    return :operations_admin if current_user.role_operations_admin?
    return :operations_staff if current_user.role_operations_staff?
    
    :limited
  end

  def operations_staff_attributes
    {
      # Operations staff only see codenames and basic status
      display_name: vip_profile.internal_codename,
      security_clearance_level: vip_profile.security_clearance_level,
      source_count: vip_profile.source_of_request_users.count
    }
  end

  def operations_admin_attributes
    operations_staff_attributes.merge({
      # Operations admin can see actual name when needed
      actual_name: vip_profile.actual_name,
      display_name: vip_profile.actual_name,
      preferences: vip_profile.all_preferences,
      sources: source_relationships_summary,
      flight_requests_count: vip_profile.flight_requests.count
    })
  end

  def full_access_attributes
    operations_admin_attributes.merge({
      # Management and super admin see everything
      created_by: {
        id: vip_profile.created_by_user.id,
        email: vip_profile.created_by_user.email
      },
      deleted_at: vip_profile.deleted_at,
      detailed_preferences: vip_profile.all_preferences,
      full_source_relationships: detailed_source_relationships
    })
  end



  def source_relationships_summary
    vip_profile.source_of_request_users.active.map do |user|
      {
        id: user.id,
        email: user.email,
        name: user.name,
        relationship_status: user.vip_sources_relationships
                                .find_by(vip_profile: vip_profile)&.status || "active"
      }
    end
  end

  def detailed_source_relationships
    vip_profile.vip_sources_relationships.includes(:user).map do |relationship|
      {
        id: relationship.id,
        user: {
          id: relationship.user.id,
          email: relationship.user.email,
          name: relationship.user.name,
          status: relationship.user.status
        },
        status: relationship.status,
        created_at: relationship.created_at,
        updated_at: relationship.updated_at
      }
    end
  end
end
