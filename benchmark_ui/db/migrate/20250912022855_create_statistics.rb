class CreateStatistics < ActiveRecord::Migration[8.0]
  def change
    create_table :statistics do |t|
      t.references :handler, null: false, foreign_key: true
      t.string :metric, null: false
      t.float :standard_deviation
      t.float :min
      t.float :max
      t.float :mean
      t.float :median
      t.float :q1
      t.float :q3
    end
  end
end
