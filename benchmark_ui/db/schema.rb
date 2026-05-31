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

ActiveRecord::Schema[8.0].define(version: 2026_05_07_000200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "comparison_runs", force: :cascade do |t|
    t.string "baseline_label", null: false
    t.string "baseline_path", null: false
    t.string "candidate_label", null: false
    t.string "candidate_path", null: false
    t.string "baseline_ref"
    t.string "candidate_ref"
    t.string "status", default: "pending", null: false
    t.boolean "passed"
    t.integer "failure_count", default: 0, null: false
    t.jsonb "environment_metadata", default: {}, null: false
    t.text "notes"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_comparison_runs_on_created_at"
    t.index ["status"], name: "index_comparison_runs_on_status"
  end

  create_table "comparison_statistics", force: :cascade do |t|
    t.bigint "comparison_run_id", null: false
    t.string "metric", null: false
    t.string "handler_type", null: false
    t.integer "per_page", null: false
    t.float "baseline_q1"
    t.float "baseline_median"
    t.float "baseline_q3"
    t.float "candidate_q1"
    t.float "candidate_median"
    t.float "candidate_q3"
    t.float "ratio"
    t.boolean "passed", default: false, null: false
    t.text "failure_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["comparison_run_id", "metric", "handler_type", "per_page"], name: "index_comparison_statistics_uniqueness", unique: true
    t.index ["comparison_run_id"], name: "index_comparison_statistics_on_comparison_run_id"
  end

  create_table "handlers", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "handler_type"
    t.index ["task_id"], name: "index_handlers_on_task_id"
  end

  create_table "samples", force: :cascade do |t|
    t.float "value", null: false
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

  add_foreign_key "comparison_statistics", "comparison_runs"
  add_foreign_key "handlers", "tasks"
  add_foreign_key "statistics", "handlers"
  add_foreign_key "test_results", "test_runs"
  add_foreign_key "test_runs", "handlers"
end
