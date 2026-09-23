# What finishing a session does to stock. Every component cooked draws its
# raw ingredient lines, scaled to the servings made; every component inside
# it that was not cooked is drawn from prepped or frozen stock. A prep
# session then adds each batch as a prepped lot, and the servings set aside
# for the freezer as a frozen one. A plate session whose dish came whole from
# stock (the easy button's frozen meal) draws the dish.
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
      batch.update!(
        stock_item: (produce(component, batch.fridge_servings, :prepped, component.shelf_life_days) if batch.fridge_servings.positive?),
        frozen_stock_item: (produce(component, batch.frozen_servings, :freezer, component.freezer_life_days) if batch.frozen_servings.positive?)
      )
    end
    @notes
  end

  def plate(session)
    cooked = session.tasks.map { |task| [ task.component, task.servings ] }.uniq { |component, _| component.id }
    dish = session.schedule_entry.dish
    draw_stocked(dish, session.schedule_entry.servings) unless cooked.any? { |component, _| component == dish }
    consume(cooked)
    @notes
  end

  private
    def consume(cooked)
      cooked_ids = cooked.map { |component, _| component.id }

      cooked.each do |component, servings|
        component.component_ingredients.includes(:ingredient, ingredient_family: :ingredients).each { |line| draw_line(line, servings) }
        component.child_parts.includes(:child).each do |part|
          next if cooked_ids.include?(part.child_id)

          draw_stocked(part.child, servings * (Cooking::Meal.serving_unit?(part.unit) ? (part.quantity || 1) : 1))
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

    def produce(component, servings, kind, keeps)
      lot = StockItem.create!(stockable: component, kind:, unit: "serving", acquired_on: Date.current, expires_on: (Date.current + keeps if keeps))
      lot.record!(servings, source: :step_production, step: component.steps.last)
      lot
    end

    def draw_stocked(component, servings)
      lots = StockItem.on_hand.stocked.where(stockable: component).first_out.to_a
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
