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
end
