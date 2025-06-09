class CreateAirports < ActiveRecord::Migration[8.0]
  def change
    create_table :airports do |t|
      t.string :iata_code
      t.string :icao_code
      t.string :name
      t.string :city
      t.string :country
      t.string :timezone
      t.decimal :latitude
      t.decimal :longitude
      t.integer :operational_status

      t.timestamps
    end
    add_index :airports, :iata_code, unique: true
    add_index :airports, :icao_code, unique: true
  end
end
