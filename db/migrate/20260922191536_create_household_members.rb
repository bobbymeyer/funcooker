class CreateHouseholdMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :household_members do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
