class CreateSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :steps do |t|
      t.references :component, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :phase, null: false, default: 0
      t.integer :mode, null: false, default: 0
      t.integer :duration_minutes
      t.text :instructions

      t.timestamps
    end
  end
end
