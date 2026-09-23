class CreateReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :receipts do |t|
      t.integer :status, null: false, default: 0
      t.string :store
      t.date :purchased_on
      t.text :source_text
      t.text :error
      t.datetime :confirmed_at

      t.timestamps
    end
  end
end
