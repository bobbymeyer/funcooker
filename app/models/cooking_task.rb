# One step of a cooking session, for so many servings. An active step is
# done in one go; a passive step with a time is started, runs on the timer
# strip while the next steps are worked, and is marked done when it is.
class CookingTask < ApplicationRecord
  belongs_to :cooking_session
  belongs_to :step

  delegate :component, :instructions, :duration_minutes, to: :step

  def timed?
    step.passive? && step.duration_minutes.to_i.positive?
  end

  def running?
    started_at.present? && completed_at.nil?
  end

  def completed?
    completed_at.present?
  end

  def ends_at
    started_at + duration_minutes.minutes if timed? && started_at
  end

  def start!
    update!(started_at: Time.current)
  end

  def complete!
    now = Time.current
    update!(started_at: started_at || now, completed_at: now)
  end

  def reopen!
    update!(started_at: nil, completed_at: nil)
  end

  # The ingredients this step uses, scaled. A step with none of its own shows
  # the whole component's on its first step, as the mise en place.
  def ingredient_lines
    lines = step.component_ingredients.to_a
    lines = component.component_ingredients.to_a if lines.empty? && first_of_component?
    lines.map { |line| [ line, line.quantity && line.quantity * servings ] }
  end

  def parts
    parts = step.component_parts.to_a
    parts = component.child_parts.to_a if parts.empty? && first_of_component?
    parts.map { |part| [ part, (part.quantity || 1) * servings ] }
  end

  private
    def first_of_component?
      step == component.steps.first
    end
end
