# So many servings of a component, made in a prep session, of which some may
# go straight into the freezer: cook once, freeze half.
class PrepBatch < ApplicationRecord
  belongs_to :cooking_session
  belongs_to :component
  belongs_to :stock_item, optional: true
  belongs_to :frozen_stock_item, class_name: "StockItem", optional: true

  validates :servings, numericality: { greater_than: 0 }
  validates :frozen_servings, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: :servings }, if: :servings
  validate :freezes, if: -> { frozen_servings.to_d.positive? }

  def fridge_servings
    servings - frozen_servings
  end

  private
    def freezes
      errors.add(:frozen_servings, "can't be frozen: #{component.name} does not freeze well") unless component.freezable?
    end
end
