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

ActiveRecord::Schema[8.0].define(version: 2026_06_20_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "event_applications", force: :cascade do |t|
    t.string "volunteer_id", null: false
    t.string "event_id", null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone"
    t.string "email"
    t.index ["volunteer_id", "event_id"], name: "index_event_applications_on_volunteer_id_and_event_id", unique: true
  end

  create_table "events", id: :string, force: :cascade do |t|
    t.string "title"
    t.string "kind"
    t.string "subtitle"
    t.string "date_label"
    t.string "time_label"
    t.string "place"
    t.string "address"
    t.string "poster"
    t.string "icon"
    t.string "badge"
    t.string "badge_bg"
    t.string "badge_fg"
    t.text "description"
    t.json "roles", default: []
    t.json "slots", default: {}
    t.integer "applications_count", default: 0
    t.integer "waitlist_count", default: 0
    t.string "status", default: "draft"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "starts_at"
    t.integer "duration_minutes"
  end

  create_table "participations", force: :cascade do |t|
    t.string "supporter_id", null: false
    t.string "event_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["supporter_id", "event_id"], name: "index_participations_on_supporter_id_and_event_id", unique: true
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "identity_id", null: false
    t.string "endpoint", null: false
    t.string "p256dh", null: false
    t.string "auth", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["identity_id"], name: "index_push_subscriptions_on_identity_id"
  end
end
