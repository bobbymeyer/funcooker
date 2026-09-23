class ReceiptParseJob < ApplicationJob
  def perform(receipt)
    receipt.parse
  end
end
