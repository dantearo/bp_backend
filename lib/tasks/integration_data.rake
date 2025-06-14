namespace :integration_data do
  desc "Seed airports and aircraft data for integration services"
  task seed: :environment do
    puts "Seeding airports..."
    airport_result = AirportDataService.seed_airports
    puts "  Created: #{airport_result[:created]} airports"
    puts "  Updated: #{airport_result[:updated]} airports"
    puts "  Total: #{airport_result[:total]} airports"

    puts "\nSeeding aircraft..."
    aircraft_result = AircraftAvailabilityService.seed_sample_aircraft
    puts "  Created: #{aircraft_result[:created]} aircraft"
    puts "  Updated: #{aircraft_result[:updated]} aircraft"
    puts "  Total: #{aircraft_result[:total]} aircraft"

    puts "\nIntegration services data seeded successfully!"
  end

  desc "Display integration services statistics"
  task stats: :environment do
    puts "Integration Services Statistics:"
    puts "  Airports: #{Airport.count} total (#{Airport.operational.count} operational)"
    puts "  Aircraft: #{Aircraft.count} total (#{Aircraft.available.count} available)"
    puts "  Security Clearance Levels: #{FlightConstraintsService::SECURITY_CLEARANCES.size}"
    puts "  Restricted Airports: #{FlightConstraintsService::RESTRICTED_AIRPORTS.size}"
  end
end
