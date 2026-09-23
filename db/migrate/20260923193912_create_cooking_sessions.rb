class CreateCookingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :components, :shelf_life_days, :integer

    create_table :cooking_sessions do |t|
      t.integer :kind, null: false
      t.integer :status, null: false, default: 0
      t.references :schedule_entry, foreign_key: true
      t.text :error
      t.text :stock_notes
      t.datetime :finished_at
      t.timestamps
    end

    create_table :prep_batches do |t|
      t.references :cooking_session, null: false, foreign_key: true
      t.references :component, null: false, foreign_key: true
      t.decimal :servings, null: false
      t.references :stock_item, foreign_key: true
      t.timestamps
    end

    create_table :cooking_tasks do |t|
      t.references :cooking_session, null: false, foreign_key: true
      t.references :step, null: false, foreign_key: true
      t.decimal :servings, null: false
      t.integer :position, null: false
      t.string :cluster
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end
  end
end
