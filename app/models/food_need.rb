# What one member cannot eat (a restriction: the scheduler never plans it) or
# likes or dislikes (a preference: it only moves a dish's score).
class FoodNeed < ApplicationRecord
  SUBJECT_TYPES = %w[Ingredient IngredientFamily Component].freeze

  belongs_to :household_member
  belongs_to :subject, polymorphic: true

  enum :tier, { restriction: 0, preference: 1 }, validate: true
  enum :sentiment, { likes: 1, dislikes: -1 }, validate: true

  validates :subject_type, inclusion: { in: SUBJECT_TYPES }
  validates :subject_id, uniqueness: { scope: [ :household_member_id, :subject_type ], message: "already has a need for this member" }

  # For the form: "Ingredient:3".
  def subject_key
    "#{subject_type}:#{subject_id}" if subject
  end

  def subject_key=(key)
    type, id = key.to_s.split(":", 2)
    self.subject = type.in?(SUBJECT_TYPES) ? type.constantize.find_by(id:) : nil
  end

  def describe
    restriction? ? "can't eat #{subject.name}" : "#{sentiment} #{subject.name}"
  end
end
