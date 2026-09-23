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

  test "off macOS there is no send button, and the page says why" do
    get shopping_list_path

    assert_select "button", text: "Send to Reminders", count: 0
    assert_select "p.hint", /needs the app running on the Mac itself/
  end

  test "on a Mac, send adds the list to Reminders" do
    defaults = [ Reminders.mac, Reminders.osascript, Reminders.runner ]
    sent = nil
    Reminders.mac = -> { true }
    Reminders.osascript = -> { "/usr/bin/osascript" }
    Reminders.runner = ->(*command) { sent = JSON.parse(command.last); [ '{"list":"Groceries","added":1,"skipped":0}', "", Struct.new(:success?, :exitstatus).new(true, 0) ] }

    get shopping_list_path
    assert_select "button", "Send to Reminders"

    post remind_shopping_list_path(days: 3)

    assert_redirected_to shopping_list_path(days: 3)
    assert_equal "Added 1 item to Groceries.", flash[:notice]
    assert_equal "corn tortilla, 3", sent["items"].sole["title"]
  ensure
    Reminders.mac, Reminders.osascript, Reminders.runner = defaults
  end

  test "a send that fails says why" do
    post remind_shopping_list_path

    assert_match "not running on macOS", flash[:alert]
  end
end
