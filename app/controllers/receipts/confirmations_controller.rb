class Receipts::ConfirmationsController < ApplicationController
  def create
    @receipt = Receipt.find(params[:receipt_id])

    if @receipt.parsed? && @receipt.confirm(confirmation_params)
      redirect_to @receipt, notice: "Stocked."
    else
      render "receipts/show", status: :unprocessable_entity
    end
  end

  private
    def confirmation_params
      params.expect(receipt: [ lines_attributes: [ %i[ id included ingredient_name quantity unit expires_on ] ] ])
    end
end
