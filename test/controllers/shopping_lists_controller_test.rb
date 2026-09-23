require "test_helper"

class ShoppingListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    HouseholdMember.create!(name: "Bobby")
    tacos = Component.create!(name: "tacos")
    tacos.component_ingredients.create!(ingredient: Ingredient.create!(name: "corn tortilla"), quantity: 3)
    ScheduleEntry.create!(served_on: Date.current, dish: tacos)
  end

  test "the page lists what to buy, with the copy button and the Shortcut steps" do
    get shopping_list_path

    assert_select "td", /corn tortilla, 3/
    assert_select "textarea[data-copy-target=source]", "corn tortilla, 3"
    assert_select "button", "Copy for Reminders"
    assert_select "code", "http://www.example.com/shopping.json"
  end

  test "plain text, one item per line" do
    get shopping_list_path(format: :text)

    assert_equal "corn tortilla, 3", response.body
  end

  test "JSON for a Shortcut" do
    get shopping_list_path(format: :json, days: 3)

    body = response.parsed_body
    assert_equal [ "Groceries", 3 ], [ body["list"], body["days"] ]
    assert_equal "corn tortilla, 3", body["items"].sole["title"]
    assert_match "for tacos", body["items"].sole["notes"]
  end

  test "nothing planned" do
    ScheduleEntry.destroy_all

    get shopping_list_path
    assert_select "p.empty", /Nothing planned/
  end
end
