class Alert < ApplicationRecord
  belongs_to :flight_request
  belongs_to :user
  belongs_to :acknowledged_by, class_name: "User", optional: true
  has_many :notifications, dependent: :destroy

  validates :alert_type, presence: true
  validates :title, presence: true
  validates :message, presence: true
  validates :priority, presence: true
  validates :status, presence: true

  enum :alert_type, {
    timeline: 0,
    status_change: 1,
    escalation: 2,
    system: 3
  }

  enum :priority, {
    low: 1,
    medium: 2,
    high: 3,
    urgent: 4,
    critical: 5
  }

  enum :status, {
    active: 0,
    acknowledged: 1,
    dismissed: 2,
    escalated: 3
  }

  scope :unacknowledged, -> { where(status: :active) }
  scope :for_user, ->(user) { where(user: user) }
  scope :by_priority, -> { order(priority: :desc, created_at: :asc) }

  def acknowledge!(user)
    self.status = :acknowledged
    self.acknowledged_at = Time.current
    self.acknowledged_by = user
    save!
  end

  def escalate!
    update!(status: :escalated, escalated_at: Time.current, escalation_level: (escalation_level || 0) + 1)
  end

  def time_until_flight
    return nil unless flight_request&.departure_time
    
    flight_request.departure_time - Time.current
  end

  def hours_until_flight
    seconds = time_until_flight
    return nil unless seconds
    
    (seconds / 1.hour).round(1)
  end
end
