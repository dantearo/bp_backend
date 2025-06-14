class CreateAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :alerts do |t|
      t.string :alert_type
      t.references :flight_request, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :message
      t.integer :priority
      t.integer :status
      t.datetime :acknowledged_at
      t.references :acknowledged_by, null: true, foreign_key: { to_table: :users }
      t.datetime :escalated_at
      t.integer :escalation_level
      t.json :metadata

      t.timestamps
    end
  end
end
