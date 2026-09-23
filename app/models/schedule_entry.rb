# One meal slot on one day, and who is eating it. A new meal starts with
# everyone who eats by default. A dish that anyone at the meal is restricted
# from is refused: a restriction is something they do not eat.
#
# origin says who put it there: by hand, derived by the planner (and so
# replaced whenever the plan is derived again), or the easy button.
class ScheduleEntry < ApplicationRecord
  class NothingFrozen < StandardError; end

  belongs_to :dish, class_name: "Component", inverse_of: :schedule_entries
  has_many :meal_diners, dependent: :destroy
  has_many :diners, through: :meal_diners, source: :household_member
  has_many :cooking_sessions, dependent: :nullify

  enum :meal_slot, { breakfast: 0, lunch: 1, dinner: 2 }, validate: true
  enum :status, { planned: 0, served: 1, skipped: 2, swapped: 3 }, validate: true
  enum :origin, { manual: 0, derived: 1, easy: 2 }, validate: true

  scope :active, -> { where(status: %i[ planned served ]) }
  scope :chronological, -> { order(:served_on, :meal_slot, :id) }

  validates :served_on, presence: true
  validate :dish_is_a_dish
  validate :respects_restrictions
  validate :one_meal_per_slot

  # A skipped meal is a disruption: what was derived for the days after it is
  # derived again from what is true now.
  before_validation :seat_default_diners, on: :create

  after_update_commit -> { Schedule::Planner.rederive(from: served_on + 1) }, if: -> { saved_change_to_status? && skipped? }

  def self.up_next
    active.planned.where(served_on: Date.current..).chronological.first
  end

  def diner_ids=(ids)
    @diners_chosen = true
    super
  end

  # Adult servings the meal needs.
  def servings
    diners.sum(&:portion)
  end

  def active?
    planned? || served?
  end

  # "I'm tired": the meal is swapped for a finished dish from the freezer
  # bank, for the same people: the one that expires soonest that none of them
  # is restricted from, with enough servings for them when counted in
  # servings.
  def ease!
    eating = diners.includes(:food_needs).to_a
    lot = StockItem.on_hand.frozen_meal.includes(:stockable).order(Arel.sql("expires_on IS NULL"), :expires_on).find do |candidate|
      !candidate.stockable.restricted_for_any?(eating) && (candidate.unit.to_s.singularize != "serving" || candidate.quantity >= eating.sum(&:portion))
    end
    raise NothingFrozen, "Nothing in the freezer bank for #{eating.any? ? eating.map(&:name).to_sentence : "this meal"}" unless lot

    transaction do
      swapped!
      ScheduleEntry.create!(served_on:, meal_slot:, dish: lot.stockable, origin: :easy, diners: eating)
    end
  end

  # Diners are written as soon as they are assigned to a saved meal, so a
  # change that is then refused is rolled back with the rest.
  def revise(attributes)
    transaction do
      assign_attributes(attributes)
      save or raise ActiveRecord::Rollback
    end.present?
  end

  def restriction_conflicts
    return [] unless dish

    diners.to_a.select { |member| dish.restricted_for?(member) }
  end

  private
    def dish_is_a_dish
      errors.add(:dish, "is nested inside another component") if dish && !dish.dish?
    end

    def respects_restrictions
      conflicts = restriction_conflicts
      if conflicts.any?
        errors.add(:dish, "is something #{conflicts.map(&:name).to_sentence} #{conflicts.one? ? "doesn't" : "don't"} eat")
      end
    end

    def seat_default_diners
      self.diners = HouseholdMember.by_default.to_a unless @diners_chosen || diners.any?
    end

    def one_meal_per_slot
      return unless active? && served_on && meal_slot

      if ScheduleEntry.active.where(served_on:, meal_slot:).where.not(id:).exists?
        errors.add(:meal_slot, "already has a meal on #{served_on}")
      end
    end
end
