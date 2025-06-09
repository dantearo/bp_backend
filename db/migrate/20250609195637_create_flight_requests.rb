class CreateFlightRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :flight_requests do |t|
      t.string :request_number
      t.references :vip_profile, null: false, foreign_key: true
      t.references :source_of_request_user, null: false, foreign_key: { to_table: :users }
      t.date :flight_date
      t.string :departure_airport_code
      t.string :arrival_airport_code
      t.time :departure_time
      t.time :arrival_time
      t.integer :number_of_passengers
      t.integer :status
      t.text :unable_reason
      t.string :passenger_list_file_path
      t.string :flight_brief_file_path
      t.datetime :completed_at
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :flight_requests, :request_number, unique: true
  end
end
