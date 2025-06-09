# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_06_09_200808) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "airports", force: :cascade do |t|
    t.string "iata_code"
    t.string "icao_code"
    t.string "name"
    t.string "city"
    t.string "country"
    t.string "timezone"
    t.decimal "latitude"
    t.decimal "longitude"
    t.integer "operational_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["iata_code"], name: "index_airports_on_iata_code", unique: true
    t.index ["icao_code"], name: "index_airports_on_icao_code", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "action_type"
    t.string "resource_type"
    t.integer "resource_id"
    t.string "ip_address"
    t.text "user_agent"
    t.json "change_data"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_type"], name: "index_audit_logs_on_action_type"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "authentication_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "authentication_type"
    t.integer "status"
    t.string "ip_address"
    t.text "user_agent"
    t.string "failure_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_authentication_logs_on_created_at"
    t.index ["ip_address"], name: "index_authentication_logs_on_ip_address"
    t.index ["status"], name: "index_authentication_logs_on_status"
    t.index ["user_id"], name: "index_authentication_logs_on_user_id"
  end

  create_table "flight_request_legs", force: :cascade do |t|
    t.bigint "flight_request_id", null: false
    t.integer "leg_number"
    t.string "departure_airport_code"
    t.string "arrival_airport_code"
    t.time "departure_time"
    t.time "arrival_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["flight_request_id"], name: "index_flight_request_legs_on_flight_request_id"
  end

  create_table "flight_requests", force: :cascade do |t|
    t.string "request_number"
    t.bigint "vip_profile_id", null: false
    t.bigint "source_of_request_user_id", null: false
    t.date "flight_date"
    t.string "departure_airport_code"
    t.string "arrival_airport_code"
    t.time "departure_time"
    t.time "arrival_time"
    t.integer "number_of_passengers"
    t.integer "status"
    t.text "unable_reason"
    t.string "passenger_list_file_path"
    t.string "flight_brief_file_path"
    t.datetime "completed_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_flight_requests_on_deleted_at"
    t.index ["flight_date"], name: "index_flight_requests_on_flight_date"
    t.index ["request_number"], name: "index_flight_requests_on_request_number", unique: true
    t.index ["source_of_request_user_id", "status"], name: "index_flight_requests_on_source_of_request_user_id_and_status"
    t.index ["source_of_request_user_id"], name: "index_flight_requests_on_source_of_request_user_id"
    t.index ["status"], name: "index_flight_requests_on_status"
    t.index ["vip_profile_id", "status"], name: "index_flight_requests_on_vip_profile_id_and_status"
    t.index ["vip_profile_id"], name: "index_flight_requests_on_vip_profile_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "uae_pass_id"
    t.integer "role"
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.integer "status"
    t.datetime "deleted_at"
    t.datetime "last_login_at"
    t.integer "failed_login_attempts"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["status"], name: "index_users_on_status"
    t.index ["uae_pass_id"], name: "index_users_on_uae_pass_id", unique: true
  end

  create_table "vip_profiles", force: :cascade do |t|
    t.string "internal_codename"
    t.text "actual_name"
    t.integer "security_clearance_level"
    t.json "personal_preferences"
    t.json "standard_destinations"
    t.json "preferred_aircraft_types"
    t.text "special_requirements"
    t.text "restrictions"
    t.integer "status"
    t.bigint "created_by_user_id", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_vip_profiles_on_created_by_user_id"
    t.index ["deleted_at"], name: "index_vip_profiles_on_deleted_at"
    t.index ["internal_codename"], name: "index_vip_profiles_on_internal_codename", unique: true
    t.index ["status"], name: "index_vip_profiles_on_status"
  end

  create_table "vip_sources_relationships", force: :cascade do |t|
    t.bigint "vip_profile_id", null: false
    t.bigint "source_of_request_user_id", null: false
    t.string "delegation_level"
    t.string "approval_authority"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_of_request_user_id", "status"], name: "idx_on_source_of_request_user_id_status_ef8394005c"
    t.index ["source_of_request_user_id"], name: "index_vip_sources_relationships_on_source_of_request_user_id"
    t.index ["vip_profile_id", "status"], name: "index_vip_sources_relationships_on_vip_profile_id_and_status"
    t.index ["vip_profile_id"], name: "index_vip_sources_relationships_on_vip_profile_id"
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "authentication_logs", "users"
  add_foreign_key "flight_request_legs", "flight_requests"
  add_foreign_key "flight_requests", "users", column: "source_of_request_user_id"
  add_foreign_key "flight_requests", "vip_profiles"
  add_foreign_key "vip_profiles", "users", column: "created_by_user_id"
  add_foreign_key "vip_sources_relationships", "users", column: "source_of_request_user_id"
  add_foreign_key "vip_sources_relationships", "vip_profiles"
end
