# Moves servings of a frozen lot to the fridge, to use in the days ahead.
class StockItems::ThawingsController < ApplicationController
  def create
    lot = StockItem.find(params[:stock_item_id])
    thawed = lot.thaw!(params[:servings].presence || lot.quantity)
    redirect_back_or_to freezer_path, notice: "Moved #{helpers.amount_of(thawed)} of #{lot.stockable.name} to the fridge#{", use by #{l(thawed.expires_on, format: :long)}" if thawed.expires_on}."
  rescue StockItem::CannotMove => e
    redirect_back_or_to freezer_path, alert: "#{e.message}."
  end
end
