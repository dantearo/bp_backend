class CreateAircrafts < ActiveRecord::Migration[8.0]
  def change
    create_table :aircrafts do |t|
      t.string :tail_number
      t.string :aircraft_type
      t.integer :capacity
      t.string :operational_status
      t.string :home_base
      t.string :maintenance_status

      t.timestamps
    end
  end
end
