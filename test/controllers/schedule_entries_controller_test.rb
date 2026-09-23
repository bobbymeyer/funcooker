require "test_helper"

class ScheduleEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @chili = Component.create!(name: "chili")
    @chili.component_ingredients.create!(ingredient: Ingredient.create!(name: "ground beef"), quantity: 0.25, unit: "lb")
    @curry = Component.create!(name: "curry")
  end

  test "index shows up next and the plan" do
    ScheduleEntry.create!(served_on: Date.current, dish: @chili)

    get schedule_entries_path
    assert_select ".up-next a", "chili"
    assert_select "button", "I'm tired"
  end

  test "plan fills the chosen meals" do
    post plan_schedule_entries_path, params: { plan: { from: Date.current.iso8601, days: "3", meal_slots: [ "", "dinner", "lunch" ] } }

    assert_redirected_to schedule_entries_path
    assert_equal "Planned 6 meals.", flash[:notice]
    assert_equal 6, ScheduleEntry.derived.count
  end

  test "plan with no meals picked" do
    post plan_schedule_entries_path, params: { plan: { from: Date.current.iso8601, days: "3", meal_slots: [ "" ] } }
    assert_equal "Pick at least one meal to plan.", flash[:alert]
  end

  test "plan when nothing can be eaten" do
    member = HouseholdMember.create!(name: "kid")
    member.food_needs.create!(subject: @chili, tier: :restriction)
    member.food_needs.create!(subject: @curry, tier: :restriction)

    post plan_schedule_entries_path, params: { plan: { from: Date.current.iso8601, days: "3", meal_slots: [ "dinner" ] } }
    assert_equal "There is no dish everyone who eats by default can eat.", flash[:alert]
  end

  test "add, edit and delete a meal by hand" do
    get new_schedule_entry_path
    assert_response :success

    post schedule_entries_path, params: { schedule_entry: { served_on: Date.current.iso8601, meal_slot: "dinner", dish_id: @chili.id } }
    entry = ScheduleEntry.last
    assert entry.manual?

    get edit_schedule_entry_path(entry)
    assert_response :success
    patch schedule_entry_path(entry), params: { schedule_entry: { dish_id: @curry.id } }
    assert_equal @curry, entry.reload.dish

    delete schedule_entry_path(entry)
    assert_not ScheduleEntry.exists?(entry.id)
  end

  test "a derived meal changed by hand is kept from then on" do
    entry = ScheduleEntry.create!(served_on: Date.current, dish: @chili, origin: :derived)

    patch schedule_entry_path(entry), params: { schedule_entry: { dish_id: @curry.id } }

    assert entry.reload.manual?
  end

  test "a dish someone at the meal does not eat is refused" do
    kid = HouseholdMember.create!(name: "kid")
    kid.food_needs.create!(subject: @chili, tier: :restriction)

    post schedule_entries_path, params: { schedule_entry: { served_on: Date.current.iso8601, meal_slot: "dinner", dish_id: @chili.id, diner_ids: [ "", kid.id ] } }

    assert_response :unprocessable_entity
    assert_select "li", "Dish is something kid doesn't eat"
  end

  test "who is eating is chosen per meal, defaults ticked" do
    bobby = HouseholdMember.create!(name: "Bobby")
    nan = HouseholdMember.create!(name: "Nan", eats_by_default: false, portion: 0.75)

    get new_schedule_entry_path
    assert_select "input[type=checkbox][value='#{bobby.id}'][checked]"
    assert_select "input[type=checkbox][value='#{nan.id}']:not([checked])"
    assert_select "label", "Nan (0.75)"

    post schedule_entries_path, params: { schedule_entry: { served_on: Date.current.iso8601, meal_slot: "dinner", dish_id: @chili.id, diner_ids: [ "", bobby.id, nan.id ] } }
    entry = ScheduleEntry.last
    assert_equal [ bobby, nan ], entry.diners.order(:name)

    get schedule_entries_path
    assert_select "td", "Bobby, Nan"
    assert_select "td.numeric", "1.75"

    patch schedule_entry_path(entry), params: { schedule_entry: { diner_ids: [ "", bobby.id ] } }
    assert_equal [ bobby ], entry.reload.diners
  end

  test "serve, skip and ease" do
    entry = ScheduleEntry.create!(served_on: Date.current, dish: @chili)
    post serve_schedule_entry_path(entry)
    assert entry.reload.served?

    entry = ScheduleEntry.create!(served_on: Date.current + 1, dish: @chili)
    post skip_schedule_entry_path(entry)
    assert entry.reload.skipped?

    entry = ScheduleEntry.create!(served_on: Date.current + 2, dish: @chili)
    post ease_schedule_entry_path(entry)
    assert_equal "Nothing in the freezer bank for this meal.", flash[:alert]

    StockItem.create!(stockable: @curry, kind: :frozen_meal, quantity: 2)
    post ease_schedule_entry_path(entry)
    assert entry.reload.swapped?
    assert_equal @curry, ScheduleEntry.easy.last.dish
  end
end
