class AddDinersAndPortions < ActiveRecord::Migration[8.1]
  def change
    add_column :household_members, :portion, :decimal, null: false, default: 1
    add_column :household_members, :eats_by_default, :boolean, null: false, default: true

    create_table :meal_diners do |t|
      t.references :schedule_entry, null: false, foreign_key: true
      t.references :household_member, null: false, foreign_key: true
      t.timestamps
    end
    add_index :meal_diners, [ :schedule_entry_id, :household_member_id ], unique: true

    # Before this, everyone ate every meal.
    reversible do |direction|
      direction.up do
        execute <<~SQL
          INSERT INTO meal_diners (schedule_entry_id, household_member_id, created_at, updated_at)
          SELECT schedule_entries.id, household_members.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
          FROM schedule_entries CROSS JOIN household_members
        SQL
      end
    end

    remove_column :schedule_entries, :restrictions_overridden, :boolean, null: false, default: false
  end
end
