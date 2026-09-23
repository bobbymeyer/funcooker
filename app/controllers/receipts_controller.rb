class ReceiptsController < ApplicationController
  def index
    @receipts = Receipt.order(created_at: :desc)
  end

  def new
    @receipt = Receipt.new
  end

  def create
    @receipt = Receipt.new(receipt_params)

    if @receipt.save
      redirect_to @receipt
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @receipt = Receipt.find(params[:id])
  end

  # Stock already made from it stays; it is food in the kitchen.
  def destroy
    Receipt.find(params[:id]).destroy!
    redirect_to receipts_path, notice: "Deleted the receipt."
  end

  private
    def receipt_params
      params.expect(receipt: %i[ photo source_text ])
    end
end
