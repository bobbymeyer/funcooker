class ShoppingListsController < ApplicationController
  def show
    days = (params[:days] || 7).to_i.clamp(1, 28)
    @shopping_list = ShoppingList.new(days:)

    respond_to do |format|
      format.html
      format.text { render plain: @shopping_list.to_text }
      format.json do
        render json: {
          list: "Groceries",
          from: @shopping_list.from, days: @shopping_list.days,
          items: @shopping_list.items.map { |item| { title: item.title, notes: item.notes } }
        }
      end
    end
  end
end
