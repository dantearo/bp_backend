class FlightRequest < ApplicationRecord
  belongs_to :vip_profile
  belongs_to :source_of_request_user, class_name: "User"
  has_many :flight_request_legs, dependent: :destroy

  enum :status, {
    sent: 0,
    received: 1,
    under_review: 2,
    under_process: 3,
    done: 4,
    unable: 5
  }

  validates :request_number, presence: true, uniqueness: true
  validates :flight_date, presence: true
  validates :departure_airport_code, presence: true
  validates :arrival_airport_code, presence: true
  validates :number_of_passengers, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validate :either_departure_or_arrival_time_present
  validate :departure_and_arrival_different
  validate :flight_date_not_in_past

  scope :completed, -> { where(status: :done) }
  scope :pending, -> { where.not(status: [ :done, :unable ]) }
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
    return [] unless flight_date && status != "done"

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

  def either_departure_or_arrival_time_present
    if departure_time.blank? && arrival_time.blank?
      errors.add(:base, "Either departure time or arrival time must be specified")
    end
  end

  def departure_and_arrival_different
    if departure_airport_code.present? && arrival_airport_code.present? &&
       departure_airport_code == arrival_airport_code
      errors.add(:arrival_airport_code, "must be different from departure airport")
    end
  end

  def flight_date_not_in_past
    if flight_date.present? && flight_date < Date.current
      errors.add(:flight_date, "cannot be in the past")
    end
  end
end
