class CreateComparisonStatistics < ActiveRecord::Migration[8.0]
  def change
    create_table :comparison_statistics do |t|
      t.references :comparison_run, null: false, foreign_key: true
      t.string :metric, null: false
      t.string :handler_type, null: false
      t.integer :per_page, null: false
      t.float :baseline_q1
      t.float :baseline_median
      t.float :baseline_q3
      t.float :candidate_q1
      t.float :candidate_median
      t.float :candidate_q3
      t.float :ratio
      t.boolean :passed, null: false, default: false
      t.text :failure_reason
      t.timestamps
    end

    add_index :comparison_statistics,
              %i[comparison_run_id metric handler_type per_page],
              unique: true,
              name: "index_comparison_statistics_uniqueness"
  end
end