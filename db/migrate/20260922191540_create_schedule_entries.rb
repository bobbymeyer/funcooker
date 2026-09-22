class CreateScheduleEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :schedule_entries do |t|
      t.date :served_on, null: false
      t.integer :meal_slot, null: false, default: 2
      t.references :dish, null: false, foreign_key: { to_table: :components }
      t.integer :status, null: false, default: 0
      t.boolean :restrictions_overridden, null: false, default: false

      t.timestamps
    end
  end
end
