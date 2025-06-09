class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  enum :action_type, { 
    create: 0, 
    read: 1, 
    update: 2, 
    delete: 3, 
    login: 4, 
    logout: 5, 
    status_change: 6 
  }, prefix: :action

  validates :action_type, presence: true
  validates :resource_type, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_resource, ->(type, id) { where(resource_type: type, resource_id: id) }
  scope :by_user, ->(user) { where(user: user) }
end
