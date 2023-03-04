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

ActiveRecord::Schema[7.0].define(version: 2023_03_04_144230) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "devices", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "usernames", default: [], null: false, array: true
    t.string "projects", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "identifier"
    t.string "name", null: false
    t.string "webhook_url"
    t.citext "slug"
    t.index ["identifier"], name: "index_devices_on_identifier", unique: true
    t.index ["name"], name: "index_devices_on_name"
    t.index ["slug"], name: "index_devices_on_slug", unique: true
  end

  create_table "statuses", force: :cascade do |t|
    t.string "project_id"
    t.string "project_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "payload"
    t.boolean "red"
    t.boolean "yellow"
    t.string "username"
    t.string "service", null: false
    t.index ["project_id"], name: "index_statuses_on_project_id"
    t.index ["project_name"], name: "index_statuses_on_project_name"
    t.index ["red"], name: "index_statuses_on_red"
    t.index ["username", "project_name"], name: "index_statuses_on_username_and_project_name"
    t.index ["username", "red"], name: "index_statuses_on_username_and_red"
    t.index ["username", "yellow"], name: "index_statuses_on_username_and_yellow"
    t.index ["username"], name: "index_statuses_on_username"
    t.index ["yellow"], name: "index_statuses_on_yellow"
  end

end
