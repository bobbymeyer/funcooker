class CookingSessionsController < ApplicationController
  before_action :set_session, only: %i[ show destroy recipe_order finish ]

  def index
    @sessions = CookingSession.includes(schedule_entry: :dish).order(created_at: :desc)
    @up_next = ScheduleEntry.up_next
  end

  # Plan a prep session from the meals ahead.
  def new
    @days = (params[:days] || 7).to_i.clamp(1, 28)
    @suggestions = Cooking::PrepPlan.new(days: @days).suggestions
    @easy_meals = StockItem.easy_meals.count
  end

  def create
    batches = params.fetch(:batches, {}).values.filter_map do |batch|
      next unless batch[:include] == "1"

      servings = batch[:servings].to_d rescue 0
      frozen_servings = batch[:frozen_servings].to_d rescue 0
      component = Component.find_by(id: batch[:component_id])
      { component:, servings:, frozen_servings: } if component && servings.positive?
    end

    if batches.empty?
      redirect_to new_cooking_session_path, alert: "Pick at least one component, with servings above 0."
    else
      redirect_to CookingSession.prep!(batches)
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_cooking_session_path, alert: e.record.errors.full_messages.to_sentence
  end

  def show
  end

  def destroy
    @session.destroy!
    redirect_to cooking_sessions_path, notice: "Deleted the session. Stock is as it was."
  end

  def recipe_order
    @session.sequence_in_recipe_order!
    redirect_to @session
  end

  def finish
    @session.finish!
    redirect_to @session
  end

  private
    def set_session
      @session = CookingSession.includes(tasks: { step: :component }).find(params[:id])
    end
end
