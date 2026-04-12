class CreateTestResults < ActiveRecord::Migration[8.0]
  def change
    create_table :test_results do |t|
      t.references :test_run, null: false, foreign_key: true
      t.float :mean
      t.float :median
      t.float :q1
      t.float :q3
      t.float :min
      t.float :max
      t.float :standard_deviation

      t.float :duration
      t.float :memory

      t.timestamps
    end
  end
end
