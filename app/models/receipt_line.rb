# One item bought. The model's reading of it stays editable until the receipt
# is confirmed; stocking it makes a raw StockItem lot, recorded as a receipt
# transaction.
class ReceiptLine < ApplicationRecord
  belongs_to :receipt
  belongs_to :stock_item, optional: true

  normalizes :ingredient_name, with: ->(name) { name.squish.downcase.presence }
  normalizes :unit, with: ->(unit) { unit.strip.presence }

  with_options on: :confirm, if: :included? do
    validates :ingredient_name, presence: true
    validates :quantity, numericality: { greater_than: 0 }
  end

  def ingredient
    Ingredient.find_by(name: ingredient_name) if ingredient_name
  end

  def stock!
    lot = StockItem.create!(
      stockable: Ingredient.find_or_create_by!(name: ingredient_name), kind: :raw,
      unit:, acquired_on: receipt.purchased_on, expires_on:
    )
    lot.record!(quantity, source: :receipt)
    update!(stock_item: lot)
  end
end
