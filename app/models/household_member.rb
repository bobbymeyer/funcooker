class HouseholdMember < ApplicationRecord
  has_many :food_needs, dependent: :destroy

  validates :name, presence: true
end
