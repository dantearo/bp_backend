class ChangeAuditLogsUserIdToNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :audit_logs, :user_id, true
  end
end
