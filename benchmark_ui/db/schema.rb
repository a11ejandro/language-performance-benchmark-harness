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

ActiveRecord::Schema[8.0].define(version: 2025_09_12_022855) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "handlers", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "handler_type"
    t.index ["task_id"], name: "index_handlers_on_task_id"
  end

  create_table "samples", force: :cascade do |t|
    t.float "value"
  end

  create_table "statistics", force: :cascade do |t|
    t.bigint "handler_id", null: false
    t.string "metric", null: false
    t.float "standard_deviation"
    t.float "min"
    t.float "max"
    t.float "mean"
    t.float "median"
    t.float "q1"
    t.float "q3"
    t.index ["handler_id"], name: "index_statistics_on_handler_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "name"
    t.integer "page", default: 1, null: false
    t.integer "per_page", default: 20, null: false
    t.integer "runs", default: 1, null: false
    t.boolean "selected"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "test_results", force: :cascade do |t|
    t.bigint "test_run_id", null: false
    t.float "mean"
    t.float "median"
    t.float "q1"
    t.float "q3"
    t.float "min"
    t.float "max"
    t.float "standard_deviation"
    t.float "duration"
    t.float "memory"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["test_run_id"], name: "index_test_results_on_test_run_id"
  end

  create_table "test_runs", force: :cascade do |t|
    t.bigint "handler_id", null: false
    t.integer "consequent_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["handler_id"], name: "index_test_runs_on_handler_id"
  end

  add_foreign_key "handlers", "tasks"
  add_foreign_key "statistics", "handlers"
  add_foreign_key "test_results", "test_runs"
  add_foreign_key "test_runs", "handlers"
end
