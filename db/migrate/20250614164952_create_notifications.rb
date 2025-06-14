class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.string :notification_type
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :alert, null: false, foreign_key: true
      t.string :subject
      t.text :content
      t.integer :delivery_method
      t.integer :status
      t.datetime :sent_at
      t.datetime :failed_at
      t.string :failure_reason
      t.json :metadata

      t.timestamps
    end
  end
end
