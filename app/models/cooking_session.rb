# A stretch of cooking, walked through one step at a time.
#
# A prep session makes batches of components ahead: its steps are ordered by
# the model, grouped by technique and station, and finishing it adds each
# batch to stock as a prepped lot (the servings set aside for the freezer as
# a frozen one) and draws the raw ingredients it used.
#
# A plate session cooks one scheduled meal: the steps of anything in it that
# is not already prepped or frozen in stock, then the dish's own, in recipe
# order. A dish in stock whole (a frozen meal) has no steps: it is reheated.
# Finishing it draws what the meal used and marks the meal served.
class CookingSession < ApplicationRecord
  belongs_to :schedule_entry, optional: true
  has_many :prep_batches, dependent: :destroy
  has_many :tasks, -> { order(:position) }, class_name: "CookingTask", dependent: :destroy, inverse_of: :cooking_session

  enum :kind, { prep: 0, plate: 1 }, validate: true
  enum :status, { sequencing: 0, ready: 1, failed: 2, done: 3 }, validate: true

  validates :schedule_entry, presence: true, if: :plate?

  broadcasts_refreshes

  after_create_commit -> { CookingSequenceJob.perform_later(self) }, if: :sequencing?

  # batches: [{ component:, servings:, frozen_servings: }]
  def self.prep!(batches)
    transaction do
      create!(kind: :prep, status: :sequencing).tap do |session|
        batches.each do |batch|
          session.prep_batches.create!(component: batch[:component], servings: batch[:servings], frozen_servings: batch[:frozen_servings] || 0)
          batch[:component].steps.each { |step| session.tasks.build(step:, servings: batch[:servings], position: 0, cluster: batch[:component].name) }
        end
        session.tasks.each.with_index(1) { |task, position| task.position = position }
        session.save!
      end
    end
  end

  def self.plate!(entry)
    transaction do
      create!(kind: :plate, status: :ready, schedule_entry: entry).tap do |session|
        position = 0
        Cooking::Meal.new(entry).cook_now.each do |component, servings|
          component.steps.sort_by { |step| [ Step.phases.fetch(step.phase), step.position ] }.each do |step|
            session.tasks.create!(step:, servings:, position: position += 1, cluster: component.name)
          end
        end
      end
    end
  end

  def sequence
    Sequencer.new(self).call
    ready!
  rescue Llm::Error => e
    update!(status: :failed, error: e.message)
  end

  # When the model cannot order the steps: each batch in turn, in recipe order.
  def sequence_in_recipe_order!
    tasks.each.with_index(1) { |task, position| task.update!(position:) }
    update!(status: :ready, error: nil)
  end

  def current_task
    tasks.find { |task| task.started_at.nil? }
  end

  def running_tasks
    tasks.select(&:running?)
  end

  def all_done?
    tasks.all?(&:completed?)
  end

  def title
    prep? ? "prep" : schedule_entry.dish.name
  end

  def finish!
    raise ArgumentError, "Every step must be done first" unless ready? && all_done?

    transaction do
      notes = prep? ? Cooking::Stocking.new.prep(self) : Cooking::Stocking.new.plate(self)
      schedule_entry.served! if plate?
      update!(status: :done, finished_at: Time.current, stock_notes: notes.join("\n").presence)
    end
  end
end
