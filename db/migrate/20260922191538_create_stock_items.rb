class CreateStockItems < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_items do |t|
      t.references :stockable, polymorphic: true, null: false
      t.integer :kind, null: false, default: 0
      t.decimal :quantity, null: false, default: 0
      t.string :unit
      t.date :acquired_on
      t.date :expires_on

      t.timestamps
    end
  end
end
