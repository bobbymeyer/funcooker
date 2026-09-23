require "test_helper"

class FreezersControllerTest < ActionDispatch::IntegrationTest
  setup do
    HouseholdMember.create!(name: "Bobby")
    HouseholdMember.create!(name: "kid", portion: 0.5)
    @stew = Component.create!(name: "beef stew", shelf_life_days: 4, freezer_life_days: 90)
    @stock = Component.create!(name: "chicken stock", shelf_life_days: 4, freezer_life_days: 180)
    ComponentPart.create!(parent: @stew, child: @stock)
    @chili = Component.create!(name: "chili")
  end

  test "the bank counts easy meals for the household, apart from components" do
    StockItem.create!(stockable: @stew, kind: :freezer, quantity: 5, unit: "serving", expires_on: Date.current + 60)
    StockItem.create!(stockable: @stock, kind: :freezer, quantity: 8, unit: "serving", expires_on: Date.current + 100)
    entry = ScheduleEntry.create!(served_on: Date.current, dish: @chili)

    get freezer_path

    assert_select ".freezer__count strong", "3 easy meals"
    assert_select "table:first-of-type td a", "beef stew"
    assert_select "td a", "chicken stock"
    assert_select "form[action=?] button", ease_schedule_entry_path(entry, stock_item_id: StockItem.easy_meals.sole), text: "Eat next"
  end

  test "an empty bank says how to fill it" do
    get freezer_path

    assert_select "p.empty", /cook once, freeze half/
  end

  test "prepped stock about to turn is offered for freezing, if it freezes" do
    StockItem.create!(stockable: @stock, kind: :prepped, quantity: 4, unit: "serving", expires_on: Date.current + 1)
    StockItem.create!(stockable: @chili.tap { |chili| chili.update!(freezer_life_days: 0) }, kind: :prepped, quantity: 4, unit: "serving", expires_on: Date.current + 1)

    get freezer_path

    assert_select "h2", "freeze before it turns"
    assert_select "td a", text: "chicken stock"
    assert_select "td a", text: "chili", count: 0
  end

  test "freeze and thaw" do
    fridge = StockItem.create!(stockable: @stock, kind: :prepped, quantity: 4, unit: "serving", expires_on: Date.current + 1)

    post stock_item_freezing_path(fridge), params: { servings: "3" }
    assert_redirected_to freezer_path
    frozen = StockItem.freezer.sole
    assert_equal [ 1, 3, Date.current + 180 ], [ fridge.reload.quantity, frozen.quantity, frozen.expires_on ]

    post stock_item_thawing_path(frozen), params: { servings: "1" }
    assert_match "to the fridge", flash[:notice]
    assert_equal 2, frozen.reload.quantity

    post stock_item_thawing_path(frozen), params: { servings: "9" }
    assert_equal "Pick between 0 and 2 servings.", flash[:alert]
  end
end
