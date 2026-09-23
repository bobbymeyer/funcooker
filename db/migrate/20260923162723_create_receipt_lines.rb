class CreateReceiptLines < ActiveRecord::Migration[8.1]
  def change
    create_table :receipt_lines do |t|
      t.references :receipt, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :description, null: false
      t.string :ingredient_name
      t.decimal :quantity
      t.string :unit
      t.date :expires_on
      t.boolean :included, null: false, default: true
      t.references :stock_item, foreign_key: true

      t.timestamps
    end
  end
end
