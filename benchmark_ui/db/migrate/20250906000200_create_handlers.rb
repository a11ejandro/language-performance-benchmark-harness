class CreateHandlers < ActiveRecord::Migration[8.0]
  def change
    create_table :handlers do |t|
      t.references :task, null: false, foreign_key: true
      t.string :handler_type
    end
  end
end
