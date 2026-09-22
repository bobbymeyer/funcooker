class Ingredient < ApplicationRecord
  belongs_to :ingredient_family, optional: true
  has_many :component_ingredients, dependent: :restrict_with_error
  has_many :stock_items, as: :stockable, dependent: :restrict_with_error
  has_many :food_needs, as: :subject, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
