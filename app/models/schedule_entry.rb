# The household eats together, so every member's restrictions apply. An entry
# that violates one is invalid unless the override is set explicitly.
class ScheduleEntry < ApplicationRecord
  belongs_to :dish, class_name: "Component", inverse_of: :schedule_entries

  enum :meal_slot, { breakfast: 0, lunch: 1, dinner: 2 }, validate: true
  enum :status, { planned: 0, served: 1, skipped: 2, swapped: 3 }, validate: true

  validates :served_on, presence: true
  validate :dish_is_a_dish
  validate :respects_restrictions, unless: :restrictions_overridden?

  def restriction_conflicts
    return [] unless dish

    HouseholdMember.includes(:food_needs).select { |member| dish.restricted_for?(member) }
  end

  private
    def dish_is_a_dish
      errors.add(:dish, "is nested inside another component") if dish && !dish.dish?
    end

    def respects_restrictions
      conflicts = restriction_conflicts
      if conflicts.any?
        errors.add(:dish, "violates a restriction for #{conflicts.map(&:name).to_sentence}")
      end
    end
end
