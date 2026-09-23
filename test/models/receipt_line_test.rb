require "test_helper"

class ReceiptLineTest < ActiveSupport::TestCase
  setup do
    @receipt = Receipt.create!(source_text: "receipt", status: :parsed, purchased_on: Date.new(2026, 9, 20))
  end

  test "ingredient names are normalized to how ingredients are stored" do
    line = @receipt.lines.create!(position: 1, description: "CHKN", ingredient_name: "  Chicken   Breast ")

    assert_equal "chicken breast", line.ingredient_name
  end

  test "a left-out line needs nothing to confirm" do
    line = @receipt.lines.new(position: 1, description: "PAPER TOWELS", included: false)

    assert line.valid?(:confirm)
  end

  test "an included line needs an ingredient and a quantity above 0 to confirm" do
    line = @receipt.lines.new(position: 1, description: "CHKN", included: true, quantity: 0)

    assert_not line.valid?(:confirm)
    assert line.errors[:ingredient_name].any?
    assert line.errors[:quantity].any?
  end

  test "stocking reuses an existing ingredient" do
    chicken = Ingredient.create!(name: "chicken breast")
    line = @receipt.lines.create!(position: 1, description: "CHKN", ingredient_name: "chicken breast", quantity: 1, unit: "lb")

    line.stock!

    assert_equal chicken, line.stock_item.stockable
    assert_equal 1, Ingredient.count
  end
end
