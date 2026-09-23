# So many servings of a component, made in a prep session.
class PrepBatch < ApplicationRecord
  belongs_to :cooking_session
  belongs_to :component
  belongs_to :stock_item, optional: true

  validates :servings, numericality: { greater_than: 0 }
end
