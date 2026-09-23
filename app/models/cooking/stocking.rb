# What finishing a session does to stock. Every component cooked draws its
# raw ingredient lines, scaled to the servings made; every component inside
# it that was not cooked is drawn from prepped stock. A prep session then
# adds each batch as a prepped lot.
#
# Lots are drawn soonest-expiring first, and only in the unit the recipe
# measures in. What could not be drawn is returned as notes, not guessed at.
class Cooking::Stocking
  def initialize
    @notes = []
  end

  def prep(session)
    consume(session.prep_batches.map { |batch| [ batch.component, batch.servings ] })

    session.prep_batches.each do |batch|
      component = batch.component
      lot = StockItem.create!(
        stockable: component, kind: :prepped, unit: "serving", acquired_on: Date.current,
        expires_on: (Date.current + component.shelf_life_days if component.shelf_life_days)
      )
      lot.record!(batch.servings, source: :step_production, step: component.steps.last)
      batch.update!(stock_item: lot)
    end
    @notes
  end

  def plate(session)
    consume(session.tasks.map { |task| [ task.component, task.servings ] }.uniq { |component, _| component.id })
    @notes
  end

  private
    def consume(cooked)
      cooked_ids = cooked.map { |component, _| component.id }

      cooked.each do |component, servings|
        component.component_ingredients.includes(:ingredient, ingredient_family: :ingredients).each { |line| draw_line(line, servings) }
        component.child_parts.includes(:child).each do |part|
          next if cooked_ids.include?(part.child_id)

          draw_prepped(part.child, servings * (Cooking::Meal.serving_unit?(part.unit) ? (part.quantity || 1) : 1))
        end
      end
    end

    def draw_line(line, servings)
      return if line.quantity.nil?

      name = line.ingredient ? line.ingredient.name : "any #{line.ingredient_family.name}"
      ids = line.substitutable? ? line.ingredient_family.ingredients.map(&:id) : [ line.ingredient_id ]
      lots = StockItem.on_hand.raw.where(stockable_type: "Ingredient", stockable_id: ids).order(Arel.sql("expires_on IS NULL"), :expires_on, :id).to_a
      draw(name, lots, line.quantity * servings, line.unit)
    end

    def draw_prepped(component, servings)
      lots = StockItem.on_hand.prepped.where(stockable: component).order(Arel.sql("expires_on IS NULL"), :expires_on, :id).to_a
      draw(component.name, lots, servings, "serving")
    end

    def draw(name, lots, amount, unit)
      if lots.empty?
        @notes << "#{name}: none in stock"
        return
      end

      matching = lots.select { |lot| same_unit?(lot.unit, unit) }
      if matching.empty?
        @notes << "#{name}: not drawn, the recipe measures in #{unit.presence || "a count"} and stock in #{lots.map { |lot| lot.unit.presence || "a count" }.uniq.to_sentence}"
        return
      end

      remaining = amount
      matching.each do |lot|
        break unless remaining.positive?

        take = [ lot.quantity, remaining ].min
        lot.record!(-take, source: :step_consumption)
        remaining -= take
      end
      @notes << "#{name}: #{format_amount(remaining)} #{unit} short" if remaining.positive?
    end

    def same_unit?(a, b)
      normalize(a) == normalize(b)
    end

    def normalize(unit)
      unit.to_s.strip.downcase.singularize
    end

    def format_amount(amount)
      amount.round(3).to_s("F").sub(/\.0\z/, "")
    end
end
