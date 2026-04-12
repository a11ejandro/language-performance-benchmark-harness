class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.string :name
      t.integer :page, null: false, default: 1
      t.integer :per_page, null: false, default: 20
      t.integer :runs, null: false, default: 1
      t.boolean :selected
      t.timestamps
    end
  end
end
