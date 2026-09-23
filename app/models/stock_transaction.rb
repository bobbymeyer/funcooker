class StockTransaction < ApplicationRecord
  belongs_to :stock_item
  belongs_to :step, optional: true

  enum :source, { receipt: 0, manual: 1, step_consumption: 2, step_production: 3, freezer: 4 }, validate: true

  validates :delta, numericality: { other_than: 0 }
end
