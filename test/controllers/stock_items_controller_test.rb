require "test_helper"

class StockItemsControllerTest < ActionDispatch::IntegrationTest
  test "add a raw lot by hand, recorded as a manual transaction" do
    get new_stock_item_path
    assert_response :success

    post stock_items_path, params: { stock_item: { kind: "raw", ingredient_name: "Rice", quantity: "2", unit: "lb", acquired_on: "2026-09-20", expires_on: "" } }

    assert_redirected_to stock_items_path
    lot = StockItem.last
    assert_equal "rice", lot.stockable.name
    assert_equal [ [ 2, "manual" ] ], lot.stock_transactions.map { |t| [ t.delta, t.source ] }
  end

  test "add a prepped lot of a component" do
    salsa = Component.create!(name: "salsa")
    post stock_items_path, params: { stock_item: { kind: "prepped", ingredient_name: "", component_id: salsa.id, quantity: "3", unit: "serving" } }

    assert_equal salsa, StockItem.last.stockable
  end

  test "a kind that does not match what is stocked is refused" do
    post stock_items_path, params: { stock_item: { kind: "prepped", ingredient_name: "rice", quantity: "1" } }
    assert_response :unprocessable_entity
  end

  test "correcting the quantity records the difference" do
    lot = StockItem.create!(stockable: Ingredient.create!(name: "rice"), kind: :raw, quantity: 2, unit: "lb")

    get edit_stock_item_path(lot)
    assert_response :success
    patch stock_item_path(lot), params: { stock_item: { quantity: "1.5" } }

    assert_redirected_to stock_items_path
    assert_equal [ 2, -0.5 ], lot.stock_transactions.order(:id).map(&:delta)
  end

  test "destroy" do
    lot = StockItem.create!(stockable: Ingredient.create!(name: "rice"), kind: :raw, quantity: 2)

    delete stock_item_path(lot)
    assert_redirected_to stock_items_path
    assert_not StockItem.exists?(lot.id)
  end

  test "what expires soonest is listed first, under use first" do
    rice = Ingredient.create!(name: "rice")
    milk = Ingredient.create!(name: "milk")
    StockItem.create!(stockable: rice, kind: :raw, quantity: 1, expires_on: Date.current + 30)
    StockItem.create!(stockable: milk, kind: :raw, quantity: 1, expires_on: Date.current + 1)
    StockItem.create!(stockable: Ingredient.create!(name: "old bread"), kind: :raw, quantity: 1, expires_on: Date.current - 2)

    get stock_items_path

    assert_select "h2", "use first"
    assert_select "h2 + table tbody tr:first-child td", "old bread"
    assert_select "tr.stock--expired td", "expired 2 days ago"
    assert_select "td", "tomorrow"
    assert_select "h2", "then"
  end
end
