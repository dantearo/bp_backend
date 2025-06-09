class Airport < ApplicationRecord
  enum :operational_status, { 
    active: 0, 
    inactive: 1, 
    restricted: 2 
  }

  validates :iata_code, presence: true, uniqueness: true, length: { is: 3 }
  validates :icao_code, presence: true, uniqueness: true, length: { is: 4 }
  validates :name, presence: true
  validates :city, presence: true
  validates :country, presence: true
  validates :operational_status, presence: true
  validates :latitude, numericality: { in: -90..90 }, allow_blank: true
  validates :longitude, numericality: { in: -180..180 }, allow_blank: true

  scope :operational, -> { where(operational_status: :active) }
  scope :by_country, ->(country) { where(country: country) }

  def display_name
    "#{name} (#{iata_code})"
  end

  def full_location
    "#{city}, #{country}"
  end
end
