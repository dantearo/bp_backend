class CreateAuthenticationLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :authentication_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :authentication_type
      t.integer :status
      t.string :ip_address
      t.text :user_agent
      t.string :failure_reason

      t.timestamps
    end
  end
end
