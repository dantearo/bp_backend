class User < ApplicationRecord
  has_many :vip_sources_relationships, foreign_key: "source_of_request_user_id", dependent: :destroy
  has_many :vip_profiles, through: :vip_sources_relationships
  has_many :flight_requests, foreign_key: "source_of_request_user_id", dependent: :destroy
  has_many :created_vip_profiles, class_name: "VipProfile", foreign_key: "created_by_user_id"
  has_many :audit_logs, dependent: :destroy
  has_many :authentication_logs, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :received_notifications, class_name: "Notification", foreign_key: "recipient_id", dependent: :destroy
  has_many :acknowledged_alerts, class_name: "Alert", foreign_key: "acknowledged_by_id", dependent: :nullify

  enum :role, {
    source_of_request: 0,
    vip: 1,
    operations_staff: 2,
    operations_admin: 3,
    management: 4,
    super_admin: 5
  }, prefix: :role

  enum :status, { active: 0, frozen: 1, deleted: 2 }, prefix: :user

  validates :email, uniqueness: true, allow_blank: true
  validates :uae_pass_id, uniqueness: true, allow_blank: true
  validate :email_or_uae_pass_id_present
  validate :role_specific_authentication_method
  validates :role, presence: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :status, presence: true

  scope :active, -> { where(status: :active) }
  scope :not_deleted, -> { where.not(status: :deleted) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def soft_delete
    update(status: :deleted, deleted_at: Time.current)
  end

  def admin?
    role_operations_admin? || role_super_admin?
  end

  def operations_staff?
    role_operations_staff? || role_operations_admin? || role_super_admin?
  end

  def name
    full_name
  end

  def can_manage_flight_requests?
    operations_staff? || admin?
  end

  def can_delete_flight_requests?
    admin?
  end

  private

  def email_or_uae_pass_id_present
    if email.blank? && uae_pass_id.blank?
      errors.add(:base, "Either email or UAE Pass ID must be present")
    end
  end

  def role_specific_authentication_method
    if role_source_of_request? && uae_pass_id.blank?
      errors.add(:uae_pass_id, "is required for Source of Request users")
    elsif (role_operations_staff? || role_operations_admin? || role_management? || role_super_admin?) && email.blank?
      errors.add(:email, "is required for internal staff users")
    end
  end
end
