class CreateVipProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :vip_profiles do |t|
      t.string :internal_codename
      t.text :actual_name
      t.integer :security_clearance_level
      t.json :personal_preferences
      t.json :standard_destinations
      t.json :preferred_aircraft_types
      t.text :special_requirements
      t.text :restrictions
      t.integer :status
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :vip_profiles, :internal_codename, unique: true
  end
end
