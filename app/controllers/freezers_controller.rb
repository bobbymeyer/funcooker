# The freezer bank: frozen dishes ready for a night nobody wants to cook,
# frozen components, and fridge stock worth freezing before it turns.
class FreezersController < ApplicationController
  def show
    frozen = StockItem.on_hand.freezer.includes(:stockable).first_out.to_a
    @meals, @components = frozen.partition { |lot| lot.stockable.dish? }
    @household = HouseholdMember.by_default.includes(:food_needs).to_a
    @portions = @household.sum(&:portion)
    @up_next = ScheduleEntry.up_next
    @up_next_diners = @up_next&.diners&.includes(:food_needs)&.to_a
    @worth_freezing = StockItem.expiring_by(Date.current + StockItemsController::USE_FIRST_DAYS).prepped.includes(:stockable).select { |lot| lot.stockable.freezable? }
  end
end
