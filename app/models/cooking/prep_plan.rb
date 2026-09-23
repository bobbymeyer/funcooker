# What is worth prepping ahead for the meals planned in a window: every
# component inside their dishes that has steps of its own, for the servings
# those meals need, less the prepped or frozen servings already in stock. A
# meal whose dish is in stock whole needs nothing prepped.
class Cooking::PrepPlan
  def initialize(from: Date.current, days: 7)
    @entries = ScheduleEntry.active.planned.where(served_on: from...(from + days)).includes(:diners, :dish)
  end

  # [[component, servings]], most needed first.
  def suggestions
    needs = Hash.new(0)
    whole = Hash.new { |hash, dish| hash[dish] = Cooking::Meal.stocked_servings(dish) }
    @entries.each do |entry|
      if whole[entry.dish] >= entry.servings
        whole[entry.dish] -= entry.servings
      else
        Cooking::Meal.walk(entry.dish, entry.servings) { |component, servings| needs[component] += servings }
      end
    end

    needs.filter_map do |component, servings|
      short = servings - Cooking::Meal.stocked_servings(component)
      [ component, short.round(2) ] if short.positive? && component.steps.any?
    end.sort_by { |component, servings| [ -servings, component.name ] }
  end
end
