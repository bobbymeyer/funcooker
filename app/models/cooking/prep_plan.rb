# What is worth prepping ahead for the meals planned in a window: every
# component inside their dishes that has steps of its own, for the servings
# those meals need, less the prepped servings already in stock.
class Cooking::PrepPlan
  def initialize(from: Date.current, days: 7)
    @entries = ScheduleEntry.active.planned.where(served_on: from...(from + days)).includes(:diners, :dish)
  end

  # [[component, servings]], most needed first.
  def suggestions
    needs = Hash.new(0)
    @entries.each { |entry| Cooking::Meal.walk(entry.dish, entry.servings) { |component, servings| needs[component] += servings } }

    needs.filter_map do |component, servings|
      short = servings - Cooking::Meal.prepped_servings(component)
      [ component, short.round(2) ] if short.positive? && component.steps.any?
    end.sort_by { |component, servings| [ -servings, component.name ] }
  end
end
