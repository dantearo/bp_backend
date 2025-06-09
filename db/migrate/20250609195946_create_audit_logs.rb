class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :action_type
      t.string :resource_type
      t.integer :resource_id
      t.string :ip_address
      t.text :user_agent
      t.json :change_data
      t.json :metadata

      t.timestamps
    end
  end
end
