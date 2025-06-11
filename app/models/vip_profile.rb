class VipProfile < ApplicationRecord
  belongs_to :created_by_user, class_name: "User"
  has_many :vip_sources_relationships, dependent: :destroy
  has_many :source_of_request_users, through: :vip_sources_relationships
  has_many :flight_requests, dependent: :destroy

  # encrypts :actual_name # Encryption available - disabled for demo

  enum :status, { active: 0, inactive: 1, deleted: 2 }

  validates :internal_codename, presence: true, uniqueness: true
  validates :actual_name, presence: true
  validates :security_clearance_level, presence: true
  validates :status, presence: true
  validate :json_preferences_must_be_valid

  scope :active, -> { where(status: :active) }
  scope :not_deleted, -> { where.not(status: :deleted) }

  def soft_delete
    update(status: :deleted, deleted_at: Time.current)
  end

  def display_name_for_user(user)
    if user.role_operations_admin? || user.role_management? || user.role_super_admin?
      actual_name
    else
      internal_codename
    end
  end

  def codename
    internal_codename
  end

  def all_preferences
    {
      personal: personal_preferences || {},
      destinations: standard_destinations || {},
      aircraft: preferred_aircraft_types || {},
      requirements: special_requirements,
      restrictions: restrictions
    }
  end

  def update_personal_preferences(new_preferences)
    self.personal_preferences = new_preferences
    save
  end

  def update_destinations(new_destinations)
    self.standard_destinations = new_destinations
    save
  end

  def update_aircraft_preferences(new_aircraft)
    self.preferred_aircraft_types = new_aircraft
    save
  end

  private

  def json_preferences_must_be_valid
    # Rails automatically handles JSON validation for JSON columns
    # This method can be expanded for additional business logic validation
  end
end
