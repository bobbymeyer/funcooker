# Estimates how long a component keeps, in the fridge and in the freezer, with
# the model. Without overwrite, a component with both already is left alone,
# and only the blank one is filled in. A model that cannot be reached leaves
# them blank, and says so in the log.
class ShelfLifeJob < ApplicationJob
  def perform(component, overwrite: false)
    return if component.shelf_life_days && component.freezer_life_days && !overwrite

    estimate = Component::ShelfLife.estimate(component)
    attributes = {}
    attributes.merge!(shelf_life_days: estimate[:days], shelf_life_note: estimate[:note]) if overwrite || component.shelf_life_days.nil?
    attributes.merge!(freezer_life_days: estimate[:freezer_days], freezer_life_note: estimate[:freezer_note]) if overwrite || component.freezer_life_days.nil?
    component.update!(attributes)
  rescue Llm::Error => e
    Rails.logger.error("Shelf life for component #{component.id} not estimated: #{e.message}")
  end
end
