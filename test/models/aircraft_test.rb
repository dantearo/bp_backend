require "test_helper"

class AircraftTest < ActiveSupport::TestCase
  test "should create valid aircraft" do
    aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "DXB"
    )
    
    assert aircraft.valid?
    assert aircraft.save
  end

  test "should require tail number" do
    aircraft = Aircraft.new(
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "DXB"
    )
    
    assert_not aircraft.valid?
    assert aircraft.errors[:tail_number].present?
  end

  test "should require unique tail number" do
    Aircraft.create!(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "DXB"
    )
    
    duplicate_aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      aircraft_type: "Gulfstream G650",
      capacity: 8,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "AUH"
    )
    
    assert_not duplicate_aircraft.valid?
    assert duplicate_aircraft.errors[:tail_number].present?
  end

  test "should require aircraft type" do
    aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      capacity: 12,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "DXB"
    )
    
    assert_not aircraft.valid?
    assert aircraft.errors[:aircraft_type].present?
  end

  test "should require positive capacity" do
    aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 0,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "DXB"
    )
    
    assert_not aircraft.valid?
    assert aircraft.errors[:capacity].present?
  end

  test "should require operational status" do
    aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      maintenance_status: "ready",
      home_base: "DXB"
    )
    
    assert_not aircraft.valid?
    assert aircraft.errors[:operational_status].present?
  end

  test "should require maintenance status" do
    aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "active",
      home_base: "DXB"
    )
    
    assert_not aircraft.valid?
    assert aircraft.errors[:maintenance_status].present?
  end

  test "should require home base" do
    aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "active",
      maintenance_status: "ready"
    )
    
    assert_not aircraft.valid?
    assert aircraft.errors[:home_base].present?
  end

  test "should have correct display name" do
    aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "DXB"
    )
    
    assert_equal "Boeing 777-300ER - A6-PF1", aircraft.display_name
  end

  test "should be available for flight when active and ready" do
    aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "DXB"
    )
    
    assert aircraft.available_for_flight?
  end

  test "should not be available when in maintenance" do
    aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "maintenance",
      maintenance_status: "unscheduled_maintenance",
      home_base: "DXB"
    )
    
    assert_not aircraft.available_for_flight?
  end

  test "should not be available when not ready" do
    aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "active",
      maintenance_status: "scheduled_maintenance",
      home_base: "DXB"
    )
    
    assert_not aircraft.available_for_flight?
  end

  test "should have appropriate status description" do
    aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "DXB"
    )
    
    assert_equal "Available for flight operations", aircraft.status_description
  end

  test "should show maintenance status description" do
    aircraft = Aircraft.new(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "maintenance",
      maintenance_status: "major_overhaul",
      home_base: "DXB"
    )
    
    assert_equal "Aircraft in maintenance", aircraft.status_description
  end

  test "should filter available aircraft" do
    Aircraft.create!(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "DXB"
    )
    
    Aircraft.create!(
      tail_number: "A6-PF2",
      aircraft_type: "Gulfstream G650",
      capacity: 8,
      operational_status: "maintenance",
      maintenance_status: "scheduled_maintenance",
      home_base: "AUH"
    )
    
    available_aircraft = Aircraft.available
    
    assert_equal 1, available_aircraft.count
    assert_equal "A6-PF1", available_aircraft.first.tail_number
  end

  test "should filter by type" do
    Aircraft.create!(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "DXB"
    )
    
    Aircraft.create!(
      tail_number: "A6-PF2",
      aircraft_type: "Gulfstream G650",
      capacity: 8,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "AUH"
    )
    
    boeing_aircraft = Aircraft.by_type("Boeing 777-300ER")
    
    assert_equal 1, boeing_aircraft.count
    assert_equal "A6-PF1", boeing_aircraft.first.tail_number
  end

  test "should filter by minimum capacity" do
    Aircraft.create!(
      tail_number: "A6-PF1",
      aircraft_type: "Boeing 777-300ER",
      capacity: 12,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "DXB"
    )
    
    Aircraft.create!(
      tail_number: "A6-PF2",
      aircraft_type: "Gulfstream G650",
      capacity: 8,
      operational_status: "active",
      maintenance_status: "ready",
      home_base: "AUH"
    )
    
    large_aircraft = Aircraft.minimum_capacity(10)
    
    assert_equal 1, large_aircraft.count
    assert_equal "A6-PF1", large_aircraft.first.tail_number
  end
end
