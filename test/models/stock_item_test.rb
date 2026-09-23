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
    assert StockItem.new(stockable: @dish, kind: :freezer).valid?
    assert StockItem.new(stockable: @salsa, kind: :freezer).valid?

    assert_not StockItem.new(stockable: @onion, kind: :prepped).valid?
    assert_not StockItem.new(stockable: @onion, kind: :freezer).valid?
  end

  test "freezing moves servings to a lot that keeps as long as the component keeps frozen" do
    @salsa.update!(shelf_life_days: 4, freezer_life_days: 90)
    fridge = StockItem.create!(stockable: @salsa, kind: :prepped, quantity: 6, unit: "serving", expires_on: Date.current + 1)

    frozen = fridge.freeze!(4)

    assert_equal 2, fridge.reload.quantity
    assert frozen.freezer?
    assert_equal 4, frozen.quantity
    assert_equal Date.current + 90, frozen.expires_on
    assert_equal %w[ freezer ], (fridge.stock_transactions.last(1) + frozen.stock_transactions).map(&:source).uniq
  end

  test "thawing moves servings back to the fridge, keeping as long as the component keeps prepped" do
    @salsa.update!(shelf_life_days: 4, freezer_life_days: 90)
    frozen = StockItem.create!(stockable: @salsa, kind: :freezer, quantity: 4, unit: "serving", expires_on: Date.current + 60)

    thawed = frozen.thaw!(1)

    assert_equal 3, frozen.reload.quantity
    assert thawed.prepped?
    assert_equal Date.current + 4, thawed.expires_on
  end

  test "what does not freeze well, or is not there, cannot be moved" do
    @salsa.update!(freezer_life_days: 0, freezer_life_note: "turns watery")
    fridge = StockItem.create!(stockable: @salsa, kind: :prepped, quantity: 2, unit: "serving")

    error = assert_raises(StockItem::CannotMove) { fridge.freeze! }
    assert_match "turns watery", error.message

    @salsa.update!(freezer_life_days: nil)
    assert_raises(StockItem::CannotMove) { fridge.freeze!(3) }
    assert_raises(StockItem::CannotMove) { fridge.thaw! }
    assert_equal 2, fridge.reload.quantity
  end

  test "only frozen dishes are easy meals" do
    dish = StockItem.create!(stockable: @dish, kind: :freezer, quantity: 2, unit: "serving")
    StockItem.create!(stockable: @salsa, kind: :freezer, quantity: 2, unit: "serving")
    StockItem.create!(stockable: @dish, kind: :prepped, quantity: 2, unit: "serving")

    assert_equal [ dish ], StockItem.easy_meals.to_a
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
