class CreateHouseholds < ActiveRecord::Migration[8.1]
  def change
    create_table :households do |t|
      t.string :time_zone, null: false, default: "America/Los_Angeles"
      t.integer :thaw_reminder_hour, null: false, default: 16
      t.timestamps
    end
  end
end
