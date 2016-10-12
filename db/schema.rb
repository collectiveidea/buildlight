# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20161012193415) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "devices", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string   "usernames",  default: [], null: false, array: true
    t.string   "projects",   default: [], null: false, array: true
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.string   "identifier",              null: false
    t.string   "name",                    null: false
    t.index ["identifier"], name: "index_devices_on_identifier", unique: true, using: :btree
    t.index ["name"], name: "index_devices_on_name", using: :btree
  end

  create_table "statuses", force: :cascade do |t|
    t.string   "project_id"
    t.string   "project_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "payload"
    t.boolean  "red"
    t.boolean  "yellow"
    t.string   "username"
    t.string   "service",      null: false
    t.index ["project_id"], name: "index_statuses_on_project_id", using: :btree
    t.index ["project_name"], name: "index_statuses_on_project_name", using: :btree
    t.index ["red"], name: "index_statuses_on_red", using: :btree
    t.index ["username", "project_name"], name: "index_statuses_on_username_and_project_name", using: :btree
    t.index ["username", "red"], name: "index_statuses_on_username_and_red", using: :btree
    t.index ["username", "yellow"], name: "index_statuses_on_username_and_yellow", using: :btree
    t.index ["username"], name: "index_statuses_on_username", using: :btree
    t.index ["yellow"], name: "index_statuses_on_yellow", using: :btree
  end

end
