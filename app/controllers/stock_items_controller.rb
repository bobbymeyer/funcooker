class StockItemsController < ApplicationController
  USE_FIRST_DAYS = 3

  before_action :set_stock_item, only: %i[ edit update destroy ]

  def index
    @stock_items = StockItem.on_hand.includes(:stockable).order(Arel.sql("expires_on IS NULL"), :expires_on)
  end

  def new
    @stock_item = StockItem.new(acquired_on: Date.current)
  end

  def create
    @stock_item = StockItem.new(stock_item_params)

    if @stock_item.save
      redirect_to stock_items_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @stock_item.update(stock_item_params)
      redirect_to stock_items_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @stock_item.destroy!
    redirect_to stock_items_path, notice: "Deleted the #{@stock_item.stockable.name} lot."
  end

  private
    def set_stock_item
      @stock_item = StockItem.find(params[:id])
    end

    def stock_item_params
      params.expect(stock_item: %i[ kind ingredient_name component_id quantity unit acquired_on expires_on ])
    end
end
