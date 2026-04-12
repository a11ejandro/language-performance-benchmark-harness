class CreateTestRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :test_runs do |t|
      t.references :handler, null: false, foreign_key: true
      t.integer :consequent_number

      t.timestamps
    end
  end
end
