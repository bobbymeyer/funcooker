class FoodNeed < ApplicationRecord
  SUBJECT_TYPES = %w[Ingredient IngredientFamily Component].freeze

  belongs_to :household_member
  belongs_to :subject, polymorphic: true

  enum :tier, { restriction: 0, preference: 1 }, validate: true

  validates :subject_type, inclusion: { in: SUBJECT_TYPES }
  validates :subject_id, uniqueness: { scope: [ :household_member_id, :subject_type ] }
end
