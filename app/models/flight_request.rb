class FlightRequest < ApplicationRecord
  belongs_to :vip_profile
  belongs_to :source_of_request_user, class_name: "User"
  has_many :flight_request_legs, dependent: :destroy

  enum :status, {
    sent: 0,
    received: 1,
    under_review: 2,
    under_process: 3,
    completed: 4,
    done: 4,  # alias for backward compatibility
    unable: 5,
    deleted: 6
  }

  validates :request_number, presence: true, uniqueness: true
  validates :flight_date, presence: true
  validates :number_of_passengers, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validate :flight_date_not_in_past

  scope :completed, -> { where(status: [:done, :completed]) }
  scope :pending, -> { where.not(status: [:done, :completed, :unable, :deleted]) }
  scope :overdue, -> { where("flight_date < ?", Date.current).pending }
  scope :upcoming, ->(days = 7) { where(flight_date: Date.current..Date.current + days.days) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :for_vip, ->(vip_profile) { where(vip_profile: vip_profile) }
  scope :by_requester, ->(user) { where(source_of_request_user: user) }

  before_validation :generate_request_number, on: :create

  def soft_delete
    update(deleted_at: Time.current)
  end

  def overdue_alerts
    return [] unless flight_date && !["done", "completed", "unable", "deleted"].include?(status)

    hours_until_flight = ((flight_date.beginning_of_day - Time.current) / 1.hour).round
    alerts = []

    [ 72, 48, 24, 12, 6 ].each do |hours|
      alerts << hours if hours_until_flight <= hours && hours_until_flight > 0
    end

    alerts
  end

  private

  def generate_request_number
    return if request_number.present?

    year = Date.current.year
    last_request = FlightRequest.where("request_number LIKE ?", "%/#{year}")
                               .order(:request_number)
                               .last

    if last_request&.request_number
      last_number = last_request.request_number.split("/").first.to_i
      next_number = last_number + 1
    else
      next_number = 1
    end

    self.request_number = sprintf("%03d/%d", next_number, year)
  end

  def flight_date_not_in_past
    if flight_date.present? && flight_date < Date.current
      errors.add(:flight_date, "cannot be in the past")
    end
  end
end
