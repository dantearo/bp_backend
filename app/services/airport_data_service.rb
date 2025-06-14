class AirportDataService
  SAMPLE_AIRPORTS = [
    { iata_code: 'DXB', icao_code: 'OMDB', name: 'Dubai International Airport', city: 'Dubai', country: 'UAE', timezone: 'Asia/Dubai', latitude: 25.2532, longitude: 55.3657, operational_status: 'active' },
    { iata_code: 'AUH', icao_code: 'OMAA', name: 'Abu Dhabi International Airport', city: 'Abu Dhabi', country: 'UAE', timezone: 'Asia/Dubai', latitude: 24.4539, longitude: 54.6513, operational_status: 'active' },
    { iata_code: 'SHJ', icao_code: 'OMSJ', name: 'Sharjah International Airport', city: 'Sharjah', country: 'UAE', timezone: 'Asia/Dubai', latitude: 25.3285, longitude: 55.5172, operational_status: 'active' },
    { iata_code: 'LHR', icao_code: 'EGLL', name: 'London Heathrow Airport', city: 'London', country: 'United Kingdom', timezone: 'Europe/London', latitude: 51.4700, longitude: -0.4543, operational_status: 'active' },
    { iata_code: 'JFK', icao_code: 'KJFK', name: 'John F. Kennedy International Airport', city: 'New York', country: 'United States', timezone: 'America/New_York', latitude: 40.6413, longitude: -73.7781, operational_status: 'active' },
    { iata_code: 'CDG', icao_code: 'LFPG', name: 'Charles de Gaulle Airport', city: 'Paris', country: 'France', timezone: 'Europe/Paris', latitude: 49.0097, longitude: 2.5479, operational_status: 'active' },
    { iata_code: 'FRA', icao_code: 'EDDF', name: 'Frankfurt Airport', city: 'Frankfurt', country: 'Germany', timezone: 'Europe/Berlin', latitude: 50.0379, longitude: 8.5622, operational_status: 'active' },
    { iata_code: 'NRT', icao_code: 'RJAA', name: 'Narita International Airport', city: 'Tokyo', country: 'Japan', timezone: 'Asia/Tokyo', latitude: 35.7720, longitude: 140.3928, operational_status: 'active' },
    { iata_code: 'SIN', icao_code: 'WSSS', name: 'Singapore Changi Airport', city: 'Singapore', country: 'Singapore', timezone: 'Asia/Singapore', latitude: 1.3644, longitude: 103.9915, operational_status: 'active' },
    { iata_code: 'DWC', icao_code: 'OMDW', name: 'Al Maktoum International Airport', city: 'Dubai', country: 'UAE', timezone: 'Asia/Dubai', latitude: 24.8967, longitude: 55.1614, operational_status: 'active' },
    { iata_code: 'RKT', icao_code: 'OMRK', name: 'Ras Al Khaimah International Airport', city: 'Ras Al Khaimah', country: 'UAE', timezone: 'Asia/Dubai', latitude: 25.6145, longitude: 55.9388, operational_status: 'active' },
    { iata_code: 'FJR', icao_code: 'OMFJ', name: 'Fujairah International Airport', city: 'Fujairah', country: 'UAE', timezone: 'Asia/Dubai', latitude: 25.1121, longitude: 56.3240, operational_status: 'active' }
  ].freeze

  def self.seed_airports
    airports_created = 0
    airports_updated = 0

    SAMPLE_AIRPORTS.each do |airport_data|
      existing_airport = Airport.find_by(iata_code: airport_data[:iata_code])
      
      if existing_airport
        existing_airport.update!(airport_data)
        airports_updated += 1
      else
        Airport.create!(airport_data)
        airports_created += 1
      end
    end

    {
      created: airports_created,
      updated: airports_updated,
      total: SAMPLE_AIRPORTS.size
    }
  end

  def self.search_airports(query, limit: 10)
    return Airport.operational.limit(limit) if query.blank?

    Airport.operational
           .where("LOWER(name) LIKE ? OR LOWER(city) LIKE ? OR LOWER(country) LIKE ? OR UPPER(iata_code) LIKE ? OR UPPER(icao_code) LIKE ?",
                  "%#{query.downcase}%", "%#{query.downcase}%", "%#{query.downcase}%",
                  "%#{query.upcase}%", "%#{query.upcase}%")
           .limit(limit)
  end

  def self.find_by_code(code)
    return nil if code.blank?
    
    code = code.upcase.strip
    
    if code.length == 3
      Airport.find_by(iata_code: code)
    elsif code.length == 4
      Airport.find_by(icao_code: code)
    else
      nil
    end
  end

  def self.operational_status_check(airport_code)
    airport = find_by_code(airport_code)
    return { status: 'unknown', message: 'Airport not found' } unless airport

    case airport.operational_status
    when 'active'
      { status: 'operational', message: 'Airport is operational' }
    when 'inactive'
      { status: 'closed', message: 'Airport is currently closed' }
    when 'restricted'
      { status: 'restricted', message: 'Airport has operational restrictions' }
    else
      { status: 'unknown', message: 'Airport status unknown' }
    end
  end
end
