require "test_helper"

class ThawPlanTest < ActiveSupport::TestCase
  setup do
    HouseholdMember.create!(name: "Bobby")
    HouseholdMember.create!(name: "kid", portion: 0.5)

    @salsa = Component.create!(name: "salsa verde")
    @filling = Component.create!(name: "seasoned beef")
    @tacos = Component.create!(name: "tacos")
    ComponentPart.create!(parent: @tacos, child: @salsa, quantity: 1, unit: "serving")
    ComponentPart.create!(parent: @tacos, child: @filling, quantity: 1, unit: "serving")
    @stew = Component.create!(name: "beef stew")

    @tomorrow = ScheduleEntry.create!(served_on: Date.current + 1, dish: @tacos)
  end

  test "what the fridge is short of comes out of the freezer the evening before" do
    StockItem.create!(stockable: @salsa, kind: :prepped, quantity: 1, unit: "serving")
    frozen = StockItem.create!(stockable: @salsa, kind: :freezer, quantity: 4, unit: "serving", expires_on: Date.current + 60)

    thaw = ThawPlan.new.thaws.sole

    assert_equal [ @salsa, 0.5, frozen, @tomorrow ], [ thaw.component, thaw.servings, thaw.lot, thaw.entry ]
    assert_equal Date.current, thaw.by
    assert_equal Date.current.in_time_zone.change(hour: 18), thaw.due_at if Time.current.hour < 18
    assert_match "Thaw salsa verde, 0.5 servings, for #{(Date.current + 1).strftime("%A")}", thaw.title
    assert_equal [ thaw ], ThawPlan.new.due
  end

  test "a frozen dish is thawed whole, and what is inside it is not" do
    ScheduleEntry.create!(served_on: Date.current + 1, meal_slot: :lunch, dish: @stew)
    StockItem.create!(stockable: @stew, kind: :freezer, quantity: 2, unit: "serving")
    StockItem.create!(stockable: @tacos, kind: :freezer, quantity: 2, unit: "serving")
    StockItem.create!(stockable: @salsa, kind: :freezer, quantity: 2, unit: "serving")

    assert_equal [ [ "beef stew", 1.5 ], [ "tacos", 1.5 ] ], ThawPlan.new.thaws.map { |thaw| [ thaw.component.name, thaw.servings ] }.sort_by(&:first)
  end

  test "stock that does not cover a component leaves it to be cooked, with nothing thawed" do
    StockItem.create!(stockable: @salsa, kind: :freezer, quantity: 1, unit: "serving")

    assert_empty ThawPlan.new.thaws
  end

  test "lots are taken soonest-expiring first, and meals in date order share them" do
    ScheduleEntry.create!(served_on: Date.current, dish: @stew)
    later = ScheduleEntry.create!(served_on: Date.current + 1, meal_slot: :lunch, dish: @stew)
    soon = StockItem.create!(stockable: @stew, kind: :freezer, quantity: 2, unit: "serving", expires_on: Date.current + 5)
    late = StockItem.create!(stockable: @stew, kind: :freezer, quantity: 2, unit: "serving", expires_on: Date.current + 50)

    thaws = ThawPlan.new.thaws

    assert_equal [ [ soon, 1.5 ], [ soon, 0.5 ], [ late, 1 ] ], thaws.map { |thaw| [ thaw.lot, thaw.servings ] }
    assert_equal [ later, later ], thaws.last(2).map(&:entry)
    assert_equal "Thaw beef stew, 1.5 servings, for today", thaws.first.title
  end

  test "only meals in the window count" do
    @tomorrow.destroy!
    ScheduleEntry.create!(served_on: Date.current + 3, dish: @stew)
    StockItem.create!(stockable: @stew, kind: :freezer, quantity: 2, unit: "serving")

    assert_empty ThawPlan.new.thaws
    assert_equal 1, ThawPlan.new(days: 4).thaws.size
    assert_empty ThawPlan.new(days: 4).due, "due the evening before, not yet"
  end
end
