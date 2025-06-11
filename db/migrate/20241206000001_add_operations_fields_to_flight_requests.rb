class AddOperationsFieldsToFlightRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :flight_requests, :received_at, :datetime
    add_column :flight_requests, :reviewed_at, :datetime
    add_column :flight_requests, :processed_at, :datetime
    add_column :flight_requests, :unable_at, :datetime
    add_column :flight_requests, :finalized_by, :bigint
    
    add_index :flight_requests, :finalized_by
    add_foreign_key :flight_requests, :users, column: :finalized_by
  end
end
