class StockItemsController < ApplicationController
  def index
    @stock_items = StockItem.on_hand.includes(:stockable).order(Arel.sql("expires_on IS NULL"), :expires_on)
  end
end
