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

  test "a new meal seats everyone who eats by default" do
    HouseholdMember.create!(name: "Nan", eats_by_default: false)

    entry = ScheduleEntry.create!(served_on: Date.current, dish: @dish)

    assert_equal [ @kid ], entry.diners
  end

  test "only the restrictions of those eating apply" do
    nan = HouseholdMember.create!(name: "Nan", eats_by_default: false)
    nan.food_needs.create!(subject: @onion, tier: :restriction)

    entry = ScheduleEntry.create!(served_on: Date.current, dish: @dish)
    assert entry.persisted?, "Nan is not at this meal"

    assert_not entry.revise(diner_ids: [ @kid.id, nan.id ])
    assert_equal "Dish is something Nan doesn't eat", entry.errors.full_messages.sole
    assert_equal [ @kid ], entry.reload.diners, "the refused change is rolled back"
  end

  test "a meal chosen for nobody seats nobody" do
    entry = ScheduleEntry.create!(served_on: Date.current, dish: @dish, diner_ids: [])

    assert_empty entry.diners
  end

  test "servings add up the portions of those eating" do
    HouseholdMember.create!(name: "baby", portion: 0.5)

    assert_equal 1.5, ScheduleEntry.create!(served_on: Date.current, dish: @dish).servings
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
    StockItem.create!(stockable: lasagne, kind: :freezer, quantity: 4, expires_on: Date.current + 30)
    StockItem.create!(stockable: soup, kind: :freezer, quantity: 4, expires_on: Date.current + 10)
    entry = ScheduleEntry.create!(served_on: Date.current, dish: @dish)

    swap = entry.ease!

    assert entry.reload.swapped?
    assert_equal [ soup, "easy", Date.current, "dinner" ], [ swap.dish, swap.origin, swap.served_on, swap.meal_slot ]
  end

  test "the easy button keeps the same people, and needs enough servings for them" do
    HouseholdMember.create!(name: "teen", portion: 1.5)
    small = Component.create!(name: "small soup")
    big = Component.create!(name: "big stew")
    StockItem.create!(stockable: small, kind: :freezer, quantity: 2, unit: "serving", expires_on: Date.current + 1)
    StockItem.create!(stockable: big, kind: :freezer, quantity: 3, unit: "servings", expires_on: Date.current + 5)
    entry = ScheduleEntry.create!(served_on: Date.current, dish: @dish)

    swap = entry.ease!

    assert_equal big, swap.dish, "2 servings of soup are not enough for 2.5"
    assert_equal entry.diners.sort_by(&:id), swap.diners.sort_by(&:id)
  end

  test "the easy button skips frozen meals someone cannot eat" do
    StockItem.create!(stockable: Component.create!(name: "beef stew"), kind: :freezer, quantity: 4)
    @kid.food_needs.create!(subject: Component.find_by!(name: "beef stew"), tier: :restriction)
    entry = ScheduleEntry.create!(served_on: Date.current, dish: @dish)

    assert_raises(ScheduleEntry::NothingFrozen) { entry.ease! }
    assert entry.reload.planned?
  end
end
