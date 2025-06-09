class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Flight Requests - frequently queried fields
    add_index :flight_requests, :status
    add_index :flight_requests, :flight_date
    add_index :flight_requests, [:vip_profile_id, :status]
    add_index :flight_requests, [:source_of_request_user_id, :status]
    add_index :flight_requests, :deleted_at
    
    # Users - role-based queries
    add_index :users, :role
    add_index :users, :status
    add_index :users, :deleted_at
    
    # VIP Profiles - status and soft delete
    add_index :vip_profiles, :status
    add_index :vip_profiles, :deleted_at
    
    # Audit Logs - time-based queries
    add_index :audit_logs, :created_at
    add_index :audit_logs, [:resource_type, :resource_id]
    add_index :audit_logs, :action_type
    
    # Authentication Logs - security monitoring
    add_index :authentication_logs, :created_at
    add_index :authentication_logs, :status
    add_index :authentication_logs, :ip_address
    
    # VIP Sources Relationships - active relationships
    add_index :vip_sources_relationships, [:vip_profile_id, :status]
    add_index :vip_sources_relationships, [:source_of_request_user_id, :status]
  end
end
