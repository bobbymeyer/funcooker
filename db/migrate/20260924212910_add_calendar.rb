class AddCalendar < ActiveRecord::Migration[8.1]
  def change
    change_table :households, bulk: true do |t|
      t.string :prep_calendar
      t.string :busy_calendars
      t.integer :prep_day_starts, null: false, default: 8
      t.integer :prep_day_ends, null: false, default: 21
      t.datetime :calendar_read_at
    end

    create_table :busy_times do |t|
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.boolean :all_day, null: false, default: false
    end
    add_index :busy_times, :starts_at

    create_table :prep_blocks do |t|
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.json :batches, null: false, default: []
      t.references :cooking_session, foreign_key: true
      t.timestamps
    end
    add_index :prep_blocks, :starts_at
  end
end
