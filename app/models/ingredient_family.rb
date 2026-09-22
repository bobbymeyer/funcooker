class IngredientFamily < ApplicationRecord
  has_many :ingredients, dependent: :nullify
  has_many :component_ingredients, dependent: :restrict_with_error
  has_many :food_needs, as: :subject, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
