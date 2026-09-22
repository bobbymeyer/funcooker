class CreateStockTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_transactions do |t|
      t.references :stock_item, null: false, foreign_key: true
      t.decimal :delta, null: false
      t.integer :source, null: false
      t.references :step, foreign_key: true

      t.timestamps
    end
  end
end
