# Moves servings of a prepped lot into the freezer.
class StockItems::FreezingsController < ApplicationController
  def create
    lot = StockItem.find(params[:stock_item_id])
    frozen = lot.freeze!(params[:servings].presence || lot.quantity)
    redirect_back_or_to freezer_path, notice: "Froze #{helpers.amount_of(frozen)} of #{lot.stockable.name}#{", keeps until #{l(frozen.expires_on, format: :long)}" if frozen.expires_on}."
  rescue StockItem::CannotMove => e
    redirect_back_or_to freezer_path, alert: "#{e.message}."
  end
end
