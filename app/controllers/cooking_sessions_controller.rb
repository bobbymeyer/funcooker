class CookingSessionsController < ApplicationController
  include PrepBatchParams

  before_action :set_session, only: %i[ show destroy recipe_order finish ]

  def index
    @sessions = CookingSession.includes(schedule_entry: :dish).order(created_at: :desc)
    @prep_blocks = PrepBlock.upcoming
    @up_next = ScheduleEntry.up_next
  end

  # Plan a prep session from the meals ahead.
  def new
    @days = (params[:days] || 7).to_i.clamp(1, 28)
    plan = Cooking::PrepPlan.new(days: @days)
    @suggestions = plan.suggestions
    @first_need = plan.first_need
    @easy_meals = StockItem.easy_meals.count

    read_calendar_if_stale
    @estimate = Cooking::PrepEstimate.new(@suggestions.map(&:first))
    @slots = FreeTime.new(from: Time.current, to: (Date.current + @days).in_time_zone, minutes: [ @estimate.minutes, 15 ].max).slots
    @prep_blocks = PrepBlock.upcoming
  end

  def create
    batches = prep_batches

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
    # On the Mac, the calendar is read when the planner opens, at most every
    # few minutes; elsewhere it is whatever the Mac last sent.
    def read_calendar_if_stale
      read_at = Household.current.calendar_read_at
      return unless MacCalendar.available? && (read_at.nil? || read_at < 10.minutes.ago)

      MacCalendar.read!
    rescue MacScript::Error => e
      @calendar_error = e.message
    end

    def set_session
      @session = CookingSession.includes(tasks: { step: :component }).find(params[:id])
    end
end
