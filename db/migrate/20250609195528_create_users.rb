class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :uae_pass_id
      t.integer :role
      t.string :first_name
      t.string :last_name
      t.string :phone_number
      t.integer :status
      t.datetime :deleted_at
      t.datetime :last_login_at
      t.integer :failed_login_attempts

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :uae_pass_id, unique: true
  end
end
