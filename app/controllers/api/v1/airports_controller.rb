class Api::V1::AirportsController < ApplicationController
  def search
    query = params[:query]
    limit = [params[:limit]&.to_i || 10, 50].min # Max 50 results

    airports = AirportDataService.search_airports(query, limit: limit)
    
    render json: {
      success: true,
      data: airports.map do |airport|
        {
          iata_code: airport.iata_code,
          icao_code: airport.icao_code,
          name: airport.name,
          city: airport.city,
          country: airport.country,
          display_name: airport.display_name,
          full_location: airport.full_location,
          timezone: airport.timezone,
          operational_status: airport.operational_status
        }
      end,
      meta: {
        query: query,
        count: airports.size,
        limit: limit
      }
    }
  end

  def show
    code = params[:code]&.upcase&.strip
    
    if code.blank?
      render json: {
        success: false,
        error: 'Airport code is required'
      }, status: :bad_request
      return
    end

    airport = AirportDataService.find_by_code(code)
    
    unless airport
      render json: {
        success: false,
        error: 'Airport not found'
      }, status: :not_found
      return
    end

    operational_info = AirportDataService.operational_status_check(code)

    render json: {
      success: true,
      data: {
        iata_code: airport.iata_code,
        icao_code: airport.icao_code,
        name: airport.name,
        city: airport.city,
        country: airport.country,
        timezone: airport.timezone,
        latitude: airport.latitude,
        longitude: airport.longitude,
        operational_status: airport.operational_status,
        operational_info: operational_info,
        display_name: airport.display_name,
        full_location: airport.full_location
      }
    }
  end

  def operational_status
    code = params[:code]&.upcase&.strip
    
    if code.blank?
      render json: {
        success: false,
        error: 'Airport code is required'
      }, status: :bad_request
      return
    end

    status_info = AirportDataService.operational_status_check(code)
    
    render json: {
      success: true,
      data: {
        airport_code: code,
        operational_status: status_info[:status],
        message: status_info[:message],
        checked_at: Time.current.iso8601
      }
    }
  end
end
