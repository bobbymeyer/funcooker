# Someone the household cooks for. portion is how many adult servings they
# eat (recipes are stored for one adult). Those who eat by default are at
# every new meal; anyone else is added to the meals they come to.
class HouseholdMember < ApplicationRecord
  has_many :food_needs, dependent: :destroy
  has_many :meal_diners, dependent: :destroy

  scope :by_default, -> { where(eats_by_default: true) }

  validates :name, presence: true
  validates :portion, numericality: { greater_than: 0 }
end
