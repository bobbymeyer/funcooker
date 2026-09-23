class AddSchedulingFields < ActiveRecord::Migration[8.1]
  def change
    add_column :schedule_entries, :origin, :integer, null: false, default: 0
    add_index :schedule_entries, [ :served_on, :meal_slot ]
    add_column :food_needs, :sentiment, :integer, null: false, default: 1
  end
end
