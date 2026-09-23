# Estimates a component's shelf life with the model. Without overwrite, a
# component that already has one is left alone. A model that cannot be
# reached leaves it blank, and says so in the log.
class ShelfLifeJob < ApplicationJob
  def perform(component, overwrite: false)
    return if component.shelf_life_days && !overwrite

    estimate = Component::ShelfLife.estimate(component)
    component.update!(shelf_life_days: estimate[:days], shelf_life_note: estimate[:note])
  rescue Llm::Error => e
    Rails.logger.error("Shelf life for component #{component.id} not estimated: #{e.message}")
  end
end
