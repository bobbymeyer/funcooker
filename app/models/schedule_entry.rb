# One meal slot on one day. The household eats together, so every member's
# restrictions apply. An entry that violates one is invalid unless the
# override is set explicitly.
#
# origin says who put it there: by hand, derived by the planner (and so
# replaced whenever the plan is derived again), or the easy button.
class ScheduleEntry < ApplicationRecord
  class NothingFrozen < StandardError; end

  belongs_to :dish, class_name: "Component", inverse_of: :schedule_entries

  enum :meal_slot, { breakfast: 0, lunch: 1, dinner: 2 }, validate: true
  enum :status, { planned: 0, served: 1, skipped: 2, swapped: 3 }, validate: true
  enum :origin, { manual: 0, derived: 1, easy: 2 }, validate: true

  scope :active, -> { where(status: %i[ planned served ]) }
  scope :chronological, -> { order(:served_on, :meal_slot, :id) }

  validates :served_on, presence: true
  validate :dish_is_a_dish
  validate :respects_restrictions, unless: :restrictions_overridden?
  validate :one_meal_per_slot

  # A skipped meal is a disruption: what was derived for the days after it is
  # derived again from what is true now.
  after_update_commit -> { Schedule::Planner.rederive(from: served_on + 1) }, if: -> { saved_change_to_status? && skipped? }

  def self.up_next
    active.planned.where(served_on: Date.current..).chronological.first
  end

  def active?
    planned? || served?
  end

  # "I'm tired": the meal is swapped for a finished dish from the freezer
  # bank, the one that expires soonest that nobody is restricted from.
  def ease!
    members = HouseholdMember.includes(:food_needs).to_a
    lot = StockItem.on_hand.frozen_meal.includes(:stockable).order(Arel.sql("expires_on IS NULL"), :expires_on)
      .find { |candidate| !candidate.stockable.restricted_for_any?(members) }
    raise NothingFrozen, "Nothing in the freezer bank" unless lot

    transaction do
      swapped!
      ScheduleEntry.create!(served_on:, meal_slot:, dish: lot.stockable, origin: :easy)
    end
  end

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

    def one_meal_per_slot
      return unless active? && served_on && meal_slot

      if ScheduleEntry.active.where(served_on:, meal_slot:).where.not(id:).exists?
        errors.add(:meal_slot, "already has a meal on #{served_on}")
      end
    end
end
