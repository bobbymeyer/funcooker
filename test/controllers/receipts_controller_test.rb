require "test_helper"

class ReceiptsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "create from a photo" do
    assert_enqueued_jobs 1, only: ReceiptParseJob do
      post receipts_path, params: { receipt: { photo: fixture_file_upload("receipt.png", "image/png"), source_text: "" } }
    end

    assert_redirected_to Receipt.last
    assert Receipt.last.photo.attached?
  end

  test "create with nothing re-renders the form" do
    post receipts_path, params: { receipt: { source_text: "" } }
    assert_response :unprocessable_entity
  end

  test "a parsed receipt shows its lines to confirm, marking new ingredients" do
    Ingredient.create!(name: "whole milk")
    receipt = parsed_receipt

    get receipt_path(receipt)

    assert_select "input[name='receipt[lines_attributes][0][ingredient_name]'][value='chicken breast']"
    assert_select "input[name='receipt[lines_attributes][1][quantity]'][value='1']"
    assert_select "td", /BNLS SKNLS CHKN BRST\s*new/
    assert_select "td", text: /MILK/ do |cells|
      assert_no_match(/new/, cells.first.text)
    end
  end

  test "confirming stocks the lines" do
    receipt = parsed_receipt
    line = receipt.lines.first

    post receipt_confirmation_path(receipt), params: { receipt: { lines_attributes: { "0" => { id: line.id, included: "1", ingredient_name: "chicken breast", quantity: "1.5", unit: "lb", expires_on: "" } } } }

    assert_redirected_to receipt
    assert_equal 1.5, line.reload.stock_item.quantity

    get stock_items_path
    assert_select "td", "chicken breast"
  end

  test "a confirmation missing a quantity is shown again" do
    receipt = parsed_receipt
    line = receipt.lines.first

    post receipt_confirmation_path(receipt), params: { receipt: { lines_attributes: { "0" => { id: line.id, included: "1", quantity: "" } } } }

    assert_response :unprocessable_entity
    assert_select ".errors__title", /need an ingredient and a quantity/
  end

  private
    def parsed_receipt
      Receipt.create!(source_text: "receipt", status: :parsed, purchased_on: Date.new(2026, 9, 20)).tap do |receipt|
        receipt.lines.create!(position: 1, description: "BNLS SKNLS CHKN BRST", ingredient_name: "chicken breast", quantity: 1.42, unit: "lb")
        receipt.lines.create!(position: 2, description: "MILK WHOLE 1 GAL", ingredient_name: "whole milk", quantity: 1, unit: "gal")
      end
    end
end
