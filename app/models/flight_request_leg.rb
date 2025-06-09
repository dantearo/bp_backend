class FlightRequestLeg < ApplicationRecord
  belongs_to :flight_request

  validates :leg_number, presence: true, uniqueness: { scope: :flight_request_id }
  validates :departure_airport_code, presence: true
  validates :arrival_airport_code, presence: true

  scope :ordered, -> { order(:leg_number) }
end
