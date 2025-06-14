class Aircraft < ApplicationRecord
  enum :operational_status, {
    active: 0,
    inactive: 1,
    maintenance: 2,
    retired: 3
  }

  enum :maintenance_status, {
    ready: 0,
    scheduled_maintenance: 1,
    unscheduled_maintenance: 2,
    major_overhaul: 3
  }

  validates :tail_number, presence: true, uniqueness: true
  validates :aircraft_type, presence: true
  validates :capacity, presence: true, numericality: { greater_than: 0 }
  validates :operational_status, presence: true
  validates :maintenance_status, presence: true
  validates :home_base, presence: true

  scope :available, -> { where(operational_status: :active, maintenance_status: :ready) }
  scope :by_type, ->(type) { where(aircraft_type: type) }
  scope :by_base, ->(base) { where(home_base: base) }
  scope :minimum_capacity, ->(capacity) { where('capacity >= ?', capacity) }

  def display_name
    "#{aircraft_type} - #{tail_number}"
  end

  def available_for_flight?
    operational_status == 'active' && maintenance_status == 'ready'
  end

  def status_description
    if available_for_flight?
      'Available for flight operations'
    elsif operational_status == 'maintenance'
      'Aircraft in maintenance'
    elsif operational_status != 'active'
      "Aircraft #{operational_status}"
    else
      "Aircraft #{maintenance_status.humanize}"
    end
  end
end
