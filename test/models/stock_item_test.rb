require "test_helper"

class StockItemTest < ActiveSupport::TestCase
  setup do
    @onion = Ingredient.create!(name: "red onion")
    @dish = Component.create!(name: "chili")
    @salsa = Component.create!(name: "salsa")
    ComponentPart.create!(parent: @dish, child: @salsa)
  end

  test "kind must match what is stocked" do
    assert StockItem.new(stockable: @onion, kind: :raw).valid?
    assert StockItem.new(stockable: @salsa, kind: :prepped).valid?
    assert StockItem.new(stockable: @dish, kind: :frozen_meal).valid?

    assert_not StockItem.new(stockable: @onion, kind: :prepped).valid?
    assert_not StockItem.new(stockable: @salsa, kind: :frozen_meal).valid?
  end

  test "recording a transaction moves the quantity" do
    item = StockItem.create!(stockable: @onion, kind: :raw, unit: "each")
    item.record!(3, source: :receipt)
    item.record!(-1, source: :step_consumption)

    assert_equal 2, item.reload.quantity
    assert_equal 2, item.stock_transactions.count
  end

  test "expiring_by lists on-hand lots by expiry" do
    later = StockItem.create!(stockable: @onion, kind: :raw, quantity: 1, expires_on: 5.days.from_now)
    sooner = StockItem.create!(stockable: @onion, kind: :raw, quantity: 1, expires_on: 2.days.from_now)
    StockItem.create!(stockable: @onion, kind: :raw, quantity: 0, expires_on: 1.day.from_now)

    assert_equal [ sooner, later ], StockItem.expiring_by(7.days.from_now.to_date).to_a
  end
end
