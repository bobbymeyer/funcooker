# Prep sessions booked for a time, and put on the calendar.
class PrepBlocksController < ApplicationController
  include PrepBatchParams

  before_action :set_prep_block, only: %i[ edit update destroy start ]

  # From the prep planner: its ticked batches, from the start picked.
  def create
    starts_at = Time.zone.iso8601(params[:starts_at].to_s) rescue nil
    block = PrepBlock.book(prep_batches, starts_at:)

    if block.persisted?
      redirect_to cooking_sessions_path, notice: "Booked #{l(block.starts_at, format: :day_time)} to #{l(block.ends_at, format: :time)}#{" and put it on the calendar" if MacCalendar.available?}."
    else
      redirect_to new_cooking_session_path, alert: block.errors.full_messages.to_sentence
    end
  end

  def edit
  end

  def update
    @prep_block.assign_attributes(prep_block_params)
    if @prep_block.save
      redirect_to cooking_sessions_path, notice: "Saved the prep block."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @prep_block.destroy!
    redirect_to cooking_sessions_path, notice: "Deleted the prep block#{" and its calendar event" if MacCalendar.available?}."
  end

  def start
    redirect_to @prep_block.start!
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_prep_block_path(@prep_block), alert: e.record.errors.full_messages.to_sentence
  end

  private
    def set_prep_block
      @prep_block = PrepBlock.find(params[:id])
    end

    # The times, and each batch's servings; a batch with no servings is
    # dropped.
    def prep_block_params
      attributes = params.expect(prep_block: [ :starts_at, :ends_at, batches: [ [ :component_id, :servings, :frozen_servings ] ] ])
      if attributes[:batches]
        attributes[:batches] = attributes[:batches].to_h.values
          .reject { |batch| batch[:servings].to_d.zero? }
          .map { |batch| { "component_id" => batch[:component_id].to_s, "servings" => batch[:servings].to_s, "frozen_servings" => batch[:frozen_servings].presence || "0" } }
      end
      attributes
    end
end
