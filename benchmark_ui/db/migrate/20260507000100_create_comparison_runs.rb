class CreateComparisonRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :comparison_runs do |t|
      t.string :baseline_label, null: false
      t.string :baseline_path, null: false
      t.string :candidate_label, null: false
      t.string :candidate_path, null: false
      t.string :baseline_ref
      t.string :candidate_ref
      t.string :status, null: false, default: "pending"
      t.boolean :passed
      t.integer :failure_count, null: false, default: 0
      t.jsonb :environment_metadata, null: false, default: {}
      t.text :notes
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :comparison_runs, :status
    add_index :comparison_runs, :created_at
  end
end