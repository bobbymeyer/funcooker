require "test_helper"

class ScheduleEntryTest < ActiveSupport::TestCase
  setup do
    @kid = HouseholdMember.create!(name: "kid")
    @onion = Ingredient.create!(name: "red onion")
    @dish = Component.create!(name: "tacos")
    @dish.component_ingredients.create!(ingredient: @onion)
  end

  test "a restriction blocks the entry and names the member" do
    @kid.food_needs.create!(subject: @onion, tier: :restriction)
    entry = ScheduleEntry.new(served_on: Date.current, dish: @dish)

    assert_not entry.valid?
    assert_match "kid", entry.errors[:dish].first
  end

  test "an explicit override saves anyway" do
    @kid.food_needs.create!(subject: @onion, tier: :restriction)

    assert ScheduleEntry.new(served_on: Date.current, dish: @dish, restrictions_overridden: true).valid?
  end

  test "a nested component cannot be scheduled" do
    parent = Component.create!(name: "plate")
    ComponentPart.create!(parent: parent, child: @dish)

    assert_not ScheduleEntry.new(served_on: Date.current, dish: @dish).valid?
  end

  test "one active meal per slot" do
    ScheduleEntry.create!(served_on: Date.current, dish: @dish)

    assert_not ScheduleEntry.new(served_on: Date.current, dish: @dish).valid?
    assert ScheduleEntry.new(served_on: Date.current, meal_slot: :lunch, dish: @dish).valid?
    assert ScheduleEntry.new(served_on: Date.current, dish: @dish, status: :skipped).valid?
  end

  test "up next is the earliest planned meal from today" do
    ScheduleEntry.create!(served_on: Date.current - 1, dish: @dish)
    later = ScheduleEntry.create!(served_on: Date.current + 2, dish: @dish)
    soon = ScheduleEntry.create!(served_on: Date.current, meal_slot: :lunch, dish: @dish)

    assert_equal soon, ScheduleEntry.up_next
    soon.served!
    assert_equal later, ScheduleEntry.up_next
  end

  test "the easy button swaps in the frozen meal that expires soonest" do
    lasagne = Component.create!(name: "lasagne")
    soup = Component.create!(name: "soup")
    StockItem.create!(stockable: lasagne, kind: :frozen_meal, quantity: 4, expires_on: Date.current + 30)
    StockItem.create!(stockable: soup, kind: :frozen_meal, quantity: 4, expires_on: Date.current + 10)
    entry = ScheduleEntry.create!(served_on: Date.current, dish: @dish)

    swap = entry.ease!

    assert entry.reload.swapped?
    assert_equal [ soup, "easy", Date.current, "dinner" ], [ swap.dish, swap.origin, swap.served_on, swap.meal_slot ]
  end

  test "the easy button skips frozen meals someone cannot eat" do
    StockItem.create!(stockable: Component.create!(name: "beef stew"), kind: :frozen_meal, quantity: 4)
    @kid.food_needs.create!(subject: Component.find_by!(name: "beef stew"), tier: :restriction)
    entry = ScheduleEntry.create!(served_on: Date.current, dish: @dish)

    assert_raises(ScheduleEntry::NothingFrozen) { entry.ease! }
    assert entry.reload.planned?
  end
end
