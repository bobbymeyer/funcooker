class ShoppingListsController < ApplicationController
  def show
    days = (params[:days] || 7).to_i.clamp(1, 28)
    @shopping_list = ShoppingList.new(days:)

    respond_to do |format|
      format.html
      format.text { render plain: @shopping_list.to_text }
      format.json do
        render json: {
          list: Reminders.list_name,
          from: @shopping_list.from, days: @shopping_list.days,
          items: @shopping_list.items.map { |item| { title: item.title, notes: item.notes } }
        }
      end
    end
  end

  # Adds the list to Apple Reminders on this Mac.
  def remind
    days = (params[:days] || 7).to_i.clamp(1, 28)
    items = ShoppingList.new(days:).items.map { |item| { title: item.title, notes: item.notes } }
    result = Reminders.add(items)

    redirect_to shopping_list_path(days:), notice: "Added #{helpers.pluralize(result["added"], "item")} to #{result["list"]}" +
      (result["skipped"].to_i.positive? ? "; #{result["skipped"]} already there." : ".")
  rescue Reminders::Error => e
    redirect_to shopping_list_path(days:), alert: e.message
  end
end
