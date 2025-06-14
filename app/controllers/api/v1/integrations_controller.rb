class Api::V1::IntegrationsController < ApplicationController
  def check_availability
    # Extract parameters
    departure_date = params[:departure_date]
    departure_time = params[:departure_time]
    arrival_date = params[:arrival_date]
    arrival_time = params[:arrival_time]
    passenger_count = params[:passenger_count]
    aircraft_type = params[:aircraft_type]
    departure_airport = params[:departure_airport]
    arrival_airport = params[:arrival_airport]

    begin
      # Call the availability service
      result = AircraftAvailabilityService.check_availability(
        departure_date: departure_date,
        departure_time: departure_time,
        arrival_date: arrival_date,
        arrival_time: arrival_time,
        passenger_count: passenger_count,
        aircraft_type: aircraft_type,
        departure_airport: departure_airport
      )

      # Check if there were validation errors
      if result[:success] == false
        render json: result, status: :bad_request
        return
      end

      # Add additional integration checks
      integration_checks = perform_integration_checks(departure_airport, arrival_airport)
      result[:integration_checks] = integration_checks

      render json: result
    rescue StandardError => e
      Rails.logger.error "Aircraft availability check failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        success: false,
        error: 'Internal server error during availability check',
        message: 'Please try again later or contact support'
      }, status: :internal_server_error
    end
  end

  private

  def perform_integration_checks(departure_airport, arrival_airport)
    checks = {}

    # Airport operational status checks
    if departure_airport.present?
      departure_status = AirportDataService.operational_status_check(departure_airport)
      checks[:departure_airport] = departure_status
    end

    if arrival_airport.present?
      arrival_status = AirportDataService.operational_status_check(arrival_airport)
      checks[:arrival_airport] = arrival_status
    end

    # Flight constraints check (mock for now)
    checks[:flight_constraints] = FlightConstraintsService.check_basic_constraints(
      departure_airport: departure_airport,
      arrival_airport: arrival_airport
    )

    # Weather check placeholder (for future implementation)
    checks[:weather] = {
      status: 'not_implemented',
      message: 'Weather integration coming in future release'
    }

    # NOTAM check placeholder (for future implementation)
    checks[:notam] = {
      status: 'not_implemented',
      message: 'NOTAM integration coming in future release'
    }

    checks
  end
end
