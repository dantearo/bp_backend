class Notification < ApplicationRecord
  belongs_to :recipient, class_name: "User"
  belongs_to :alert

  validates :notification_type, presence: true
  validates :subject, presence: true
  validates :content, presence: true
  validates :delivery_method, presence: true
  validates :status, presence: true

  enum :notification_type, {
    alert_notification: 0,
    reminder: 1,
    escalation_notice: 2,
    status_update: 3
  }

  enum :delivery_method, {
    email: 0,
    in_app: 1,
    sms: 2,
    push: 3
  }

  enum :status, {
    pending: 0,
    sent: 1,
    failed: 2,
    delivered: 3
  }

  scope :pending_delivery, -> { where(status: :pending) }
  scope :failed_delivery, -> { where(status: :failed) }
  scope :for_user, ->(user) { where(recipient: user) }

  def mark_sent!
    update!(status: :sent, sent_at: Time.current)
  end

  def mark_failed!(reason)
    update!(status: :failed, failed_at: Time.current, failure_reason: reason)
  end

  def mark_delivered!
    update!(status: :delivered)
  end
end
