# The freezer bank: what to thaw for the meals ahead, frozen dishes ready for
# a night nobody wants to cook, frozen components, and fridge stock worth
# freezing before it turns. As JSON, what to thaw, for Reminders.
class FreezersController < ApplicationController
  def show
    @thaw_plan = ThawPlan.new(days: days)

    respond_to do |format|
      format.html { load_bank }
      format.json { render json: { list: Reminders.thaw_list_name, from: @thaw_plan.from, days: @thaw_plan.days, items: @thaw_plan.thaws.map(&:to_reminder) } }
    end
  end

  # Adds what to thaw for the days ahead to Apple Reminders on this Mac, each
  # due the evening it should come out.
  def remind
    thaws = ThawPlan.new(days:).thaws
    return redirect_to(freezer_path(days:), notice: "Nothing to thaw.") if thaws.empty?

    result = Reminders.add(thaws.map(&:to_reminder), list: Reminders.thaw_list_name)

    redirect_to freezer_path(days:), notice: "Added #{helpers.pluralize(result["added"], "reminder")} to #{result["list"]}" +
      (result["skipped"].to_i.positive? ? "; #{result["skipped"]} already there." : ".")
  rescue Reminders::Error => e
    redirect_to freezer_path(days:), alert: e.message
  end

  private
    def days
      (params[:days] || ThawPlan::DEFAULT_DAYS).to_i.clamp(1, 14)
    end

    def load_bank
      frozen = StockItem.on_hand.freezer.includes(:stockable).first_out.to_a
      @meals, @components = frozen.partition { |lot| lot.stockable.dish? }
      @household = HouseholdMember.by_default.includes(:food_needs).to_a
      @portions = @household.sum(&:portion)
      @up_next = ScheduleEntry.up_next
      @up_next_diners = @up_next&.diners&.includes(:food_needs)&.to_a
      @worth_freezing = StockItem.expiring_by(Date.current + StockItemsController::USE_FIRST_DAYS).prepped.includes(:stockable).select { |lot| lot.stockable.freezable? }
    end
end
