class ScheduleEntriesController < ApplicationController
  before_action :set_schedule_entry, only: %i[ edit update destroy serve skip ease ]

  def index
    @up_next = ScheduleEntry.up_next
    @entries = ScheduleEntry.includes(:dish).where(served_on: (Date.current - 7)..(Date.current + 28)).chronological
    @plan = { from: Date.current, days: 7, meal_slots: %w[ dinner ] }
  end

  def new
    @schedule_entry = ScheduleEntry.new(served_on: params[:served_on] || Date.current, meal_slot: params[:meal_slot] || "dinner")
  end

  def create
    @schedule_entry = ScheduleEntry.new(schedule_entry_params.merge(origin: :manual))

    if @schedule_entry.save
      redirect_to schedule_entries_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  # A derived entry changed by hand is the household's decision now, so the
  # next re-derive keeps it.
  def update
    if @schedule_entry.update(schedule_entry_params.merge(origin: @schedule_entry.easy? ? :easy : :manual))
      redirect_to schedule_entries_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @schedule_entry.destroy!
    redirect_to schedule_entries_path
  end

  def plan
    from = Date.iso8601(params.dig(:plan, :from).to_s) rescue Date.current
    days = params.dig(:plan, :days).to_i.clamp(1, 28)
    meal_slots = Array(params.dig(:plan, :meal_slots)).compact_blank & ScheduleEntry.meal_slots.keys

    if meal_slots.empty?
      redirect_to schedule_entries_path, alert: "Pick at least one meal to plan."
    elsif Component.schedulable_for(HouseholdMember.includes(:food_needs)).empty?
      redirect_to schedule_entries_path, alert: "There is no dish the whole household can eat."
    else
      planned = Schedule::Planner.derive(from:, days:, meal_slots:)
      redirect_to schedule_entries_path, notice: "Planned #{helpers.pluralize(planned.size, "meal")}."
    end
  end

  def serve
    @schedule_entry.served!
    redirect_to schedule_entries_path
  end

  def skip
    @schedule_entry.skipped!
    redirect_to schedule_entries_path, notice: "Skipped. The days after it are planned again."
  end

  def ease
    @schedule_entry.ease!
    redirect_to schedule_entries_path, notice: "Swapped for something from the freezer."
  rescue ScheduleEntry::NothingFrozen => e
    redirect_to schedule_entries_path, alert: "#{e.message}."
  end

  private
    def set_schedule_entry
      @schedule_entry = ScheduleEntry.find(params[:id])
    end

    def schedule_entry_params
      params.expect(schedule_entry: %i[ served_on meal_slot dish_id status restrictions_overridden ])
    end
end
