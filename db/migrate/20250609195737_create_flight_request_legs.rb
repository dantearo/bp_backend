class CreateFlightRequestLegs < ActiveRecord::Migration[8.0]
  def change
    create_table :flight_request_legs do |t|
      t.references :flight_request, null: false, foreign_key: true
      t.integer :leg_number
      t.string :departure_airport_code
      t.string :arrival_airport_code
      t.time :departure_time
      t.time :arrival_time

      t.timestamps
    end
  end
end
