class CreateVipSourcesRelationships < ActiveRecord::Migration[8.0]
  def change
    create_table :vip_sources_relationships do |t|
      t.references :vip_profile, null: false, foreign_key: true
      t.references :source_of_request_user, null: false, foreign_key: { to_table: :users }
      t.string :delegation_level
      t.string :approval_authority
      t.integer :status

      t.timestamps
    end
  end
end
