class AddFreezerBank < ActiveRecord::Migration[8.1]
  def change
    add_column :components, :freezer_life_days, :integer
    add_column :components, :freezer_life_note, :string
    add_column :prep_batches, :frozen_servings, :decimal, default: 0, null: false
    add_reference :prep_batches, :frozen_stock_item, foreign_key: { to_table: :stock_items }
  end
end
