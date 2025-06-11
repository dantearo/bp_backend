class VipSourcesRelationship < ApplicationRecord
  belongs_to :vip_profile
  belongs_to :source_of_request_user, class_name: "User"

  enum :status, { active: 0, inactive: 1 }

  validates :vip_profile_id, uniqueness: { scope: :source_of_request_user_id }
  validates :status, presence: true

  scope :active, -> { where(status: :active) }
end
