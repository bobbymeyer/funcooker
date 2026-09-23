require "test_helper"

class ReceiptTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  READING = {
    store: "Corner Market",
    purchased_on: "2026-09-20",
    lines: [
      { description: "BNLS SKNLS CHKN BRST", item: "chicken breast", quantity: 1.42, unit: "lb", food: true, shelf_life_days: 2 },
      { description: "2 @ MILK WHOLE 1 GAL", item: "whole milk", quantity: 2, unit: "gal", food: true, shelf_life_days: 7 },
      { description: "PAPER TOWELS 6PK", item: "paper towel", quantity: 1, unit: nil, food: false, shelf_life_days: nil }
    ]
  }.freeze

  test "pasted text is read into lines" do
    stub_llm READING

    receipt = Receipt.create!(source_text: "CORNER MARKET 09/20/26 ...")
    receipt.parse

    assert receipt.parsed?
    assert_equal "Corner Market", receipt.store
    assert_equal Date.new(2026, 9, 20), receipt.purchased_on

    chicken, milk, towels = receipt.lines
    assert_equal [ "chicken breast", 1.42, "lb", Date.new(2026, 9, 22), true ],
      [ chicken.ingredient_name, chicken.quantity, chicken.unit, chicken.expires_on, chicken.included ]
    assert_equal 2, milk.quantity
    assert_not towels.included, "non-food lines start left out"
    assert_nil towels.expires_on
  end

  test "known ingredient names are given to the model to match against" do
    Ingredient.create!(name: "chicken breast")
    Ingredient.create!(name: "whole milk")
    stub_llm READING

    Receipt.create!(source_text: "receipt").parse

    assert_requested :post, LlmStubs::LLM_URL do |request|
      JSON.parse(request.body)["messages"].first["content"].include?("Known ingredients: chicken breast, whole milk.")
    end
  end

  test "a photo goes to the vision model as an image" do
    Rails.configuration.x.llm.vision_model = "vision-model"
    stub_llm READING

    receipt = Receipt.new
    receipt.photo.attach(io: file_fixture("receipt.png").open, filename: "receipt.png", content_type: "image/png")
    receipt.save!
    receipt.parse

    assert receipt.parsed?
    assert_requested :post, LlmStubs::LLM_URL do |request|
      body = JSON.parse(request.body)
      image = body["messages"].last["content"].find { |part| part["type"] == "image_url" }
      body["model"] == "vision-model" && image["image_url"]["url"].start_with?("data:image/png;base64,")
    end
  ensure
    Rails.configuration.x.llm.vision_model = nil
  end

  test "an unreadable date falls back to the day the receipt was added" do
    stub_llm READING.merge(purchased_on: "last Tuesday")

    receipt = Receipt.create!(source_text: "receipt")
    receipt.parse

    assert_equal receipt.created_at.to_date, receipt.purchased_on
  end

  test "a receipt with no items fails" do
    stub_llm store: nil, purchased_on: nil, lines: []

    receipt = Receipt.create!(source_text: "just a coupon")
    receipt.parse

    assert receipt.failed?
    assert_equal "No items found on the receipt", receipt.error
  end

  test "confirming stocks each included line as a raw lot, recorded as a receipt transaction" do
    stub_llm READING
    receipt = Receipt.create!(source_text: "receipt")
    receipt.parse
    chicken, milk, towels = receipt.lines

    assert receipt.confirm(lines_attributes: [
      { id: chicken.id, included: "1", ingredient_name: "Chicken Breast", quantity: "1.42", unit: "lb", expires_on: "2026-09-23" },
      { id: milk.id, included: "1", ingredient_name: "whole milk", quantity: "2", unit: "gal", expires_on: "2026-09-27" },
      { id: towels.id, included: "0" }
    ])

    assert receipt.reload.confirmed?
    lot = chicken.reload.stock_item
    assert_equal Ingredient.find_by!(name: "chicken breast"), lot.stockable
    assert lot.raw?
    assert_equal [ 1.42, "lb", Date.new(2026, 9, 20), Date.new(2026, 9, 23) ], [ lot.quantity, lot.unit, lot.acquired_on, lot.expires_on ]
    assert_equal [ [ 1.42, "receipt" ] ], lot.stock_transactions.map { |t| [ t.delta, t.source ] }
    assert_nil towels.reload.stock_item
    assert_equal 2, StockItem.count
  end

  test "an included line without a quantity stops the confirmation" do
    stub_llm READING
    receipt = Receipt.create!(source_text: "receipt")
    receipt.parse
    chicken = receipt.lines.first

    assert_not receipt.confirm(lines_attributes: [ { id: chicken.id, included: "1", quantity: "" } ])
    assert receipt.lines.find { |line| line.id == chicken.id }.errors[:quantity].any?
    assert receipt.reload.parsed?
    assert_equal 0, StockItem.count
  end

  test "a receipt is confirmed only once" do
    stub_llm READING
    receipt = Receipt.create!(source_text: "receipt")
    receipt.parse
    receipt.confirm({})

    assert_raises(Receipt::Error) { receipt.confirm({}) }
    assert_equal 2, StockItem.count
  end

  test "needs exactly one of a photo or text" do
    assert_not Receipt.new.valid?

    both = Receipt.new(source_text: "receipt")
    both.photo.attach(io: file_fixture("receipt.png").open, filename: "receipt.png", content_type: "image/png")
    assert_not both.valid?

    not_an_image = Receipt.new
    not_an_image.photo.attach(io: StringIO.new("%PDF"), filename: "receipt.pdf", content_type: "application/pdf")
    assert_not not_an_image.valid?
  end

  test "creating a receipt enqueues its parse" do
    assert_enqueued_with(job: ReceiptParseJob) { Receipt.create!(source_text: "receipt") }
  end
end
