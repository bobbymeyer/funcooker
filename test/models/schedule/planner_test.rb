require "test_helper"

class Schedule::PlannerTest < ActiveSupport::TestCase
  setup do
    @today = Date.current
    @member = HouseholdMember.create!(name: "kid")
    @chili = dish("chili", "ground beef", "kidney bean")
    @tacos = dish("tacos", "ground beef", "corn tortilla")
    @curry = dish("curry", "chickpea", "coconut milk")
  end

  test "fills each slot, one meal each, in date order" do
    entries = derive(days: 3)

    assert_equal 3, entries.size
    assert_equal [ @today, @today + 1, @today + 2 ], entries.map(&:served_on)
    assert entries.all? { |entry| entry.derived? && entry.dinner? && entry.planned? }
  end

  test "a restricted dish is never planned" do
    @member.food_needs.create!(subject: Ingredient.find_by!(name: "ground beef"), tier: :restriction)

    assert_equal [ @curry ] * 1, derive(days: 1).map(&:dish)
    assert_not_includes derive(days: 5).map(&:dish), @chili
  end

  test "dishes with their ingredients on hand come first" do
    stock "chickpea"
    stock "coconut milk"

    assert_equal @curry, derive(days: 1).first.dish
  end

  test "stock about to expire pulls in the dish that uses it" do
    stock "corn tortilla", expires_on: @today + 1

    assert_equal @tacos, derive(days: 1).first.dish
  end

  test "the same dish is not repeated while others are available" do
    assert_equal 3, derive(days: 3).map(&:dish).uniq.size
  end

  test "likes and dislikes move the score" do
    @member.food_needs.create!(subject: Ingredient.find_by!(name: "coconut milk"), tier: :preference, sentiment: :likes)
    assert_equal @curry, derive(days: 1).first.dish

    ScheduleEntry.destroy_all
    @member.food_needs.destroy_all
    @member.food_needs.create!(subject: @chili, tier: :preference, sentiment: :dislikes)
    assert_not_equal @chili, derive(days: 1).first.dish
  end

  test "deriving again replaces what the planner put there, and keeps what was added by hand" do
    manual = ScheduleEntry.create!(served_on: @today + 1, meal_slot: :dinner, dish: @curry, origin: :manual)
    derive(days: 3)
    first = ScheduleEntry.derived.pluck(:id)

    derive(days: 3)

    assert ScheduleEntry.exists?(manual.id)
    assert_empty ScheduleEntry.where(id: first)
    assert_equal 3, ScheduleEntry.active.count
  end

  test "skipping a meal derives the days after it again" do
    first, second, third = derive(days: 3)
    stock "chickpea", expires_on: @today + 2
    stock "coconut milk", expires_on: @today + 2

    first.skipped!

    assert ScheduleEntry.exists?(first.id), "the skipped meal stays, as skipped"
    assert_not ScheduleEntry.exists?(second.id)
    assert_equal [ @today + 1, @today + 2 ], ScheduleEntry.derived.planned.order(:served_on).map(&:served_on)
    assert_equal @curry, ScheduleEntry.derived.planned.find_by!(served_on: @today + 1).dish, "now that curry's stock is expiring"
    assert third
  end

  test "ties go to the dish name" do
    assert_equal "chili", derive(days: 1).first.dish.name
  end

  private
    def derive(days:, meal_slots: %w[ dinner ])
      Schedule::Planner.derive(from: @today, days:, meal_slots:)
    end

    def dish(name, *ingredients)
      Component.create!(name:).tap do |component|
        ingredients.each { |ingredient| component.component_ingredients.create!(ingredient: Ingredient.find_or_create_by!(name: ingredient), quantity: 1) }
      end
    end

    def stock(name, expires_on: nil)
      StockItem.create!(stockable: Ingredient.find_by!(name:), kind: :raw, quantity: 1, expires_on:)
    end
end
