# What to buy for the meals planned ahead: everything they need, scaled to
# each meal's servings, less what is on hand, rounded up to whole packs where
# an ingredient's pack size is known.
#
# Meals are taken in date order. A component (or a whole dish) already
# prepped or frozen in stock covers as many servings as it has, meal by meal; the rest is cooked, and so needs
# its ingredients. Stock on hand is subtracted only in the unit the recipe
# measures in: an ingredient needed in cups and stocked in pounds is listed,
# with a note, not converted.
class ShoppingList
  Item = Struct.new(:name, :unit, :needed, :on_hand, :to_buy, :packs, :pack, :to_taste, :meals, :note, keyword_init: true) do
    def title
      amount = if to_taste
        nil
      elsif packs
        "#{packs} × #{format(pack)} #{unit}".squish
      else
        "#{format(to_buy)} #{unit}".squish
      end
      [ name, amount ].compact.join(", ")
    end

    def notes
      meals_part = "for #{meals.map { |entry| "#{entry.dish.name} (#{entry.served_on.strftime("%a %-d %b")})" }.uniq.to_sentence}"
      need_part = "need #{[ format(needed), unit ].compact_blank.join(" ")}, have #{format(on_hand)}" unless to_taste
      [ meals_part, need_part, note ].compact.join(". ")
    end

    private
      def format(value)
        value.to_d.round(2).to_s("F").sub(/\.0\z/, "")
      end
  end

  attr_reader :from, :days

  def initialize(from: Date.current, days: 7)
    @from, @days = from, days
  end

  def entries
    @entries ||= ScheduleEntry.active.planned.where(served_on: from...(from + days)).includes(:dish, :diners).chronological.to_a
  end

  def items
    @items ||= build
  end

  def to_text
    items.map(&:title).join("\n")
  end

  private
    def build
      @prepped = StockItem.on_hand.stocked.select { |lot| Cooking::Meal.serving_unit?(lot.unit) }.group_by(&:stockable_id).transform_values { |lots| lots.sum(&:quantity) }
      @needs = {}
      entries.each { |entry| need(entry.dish, cover(entry.dish, entry.servings), entry) }

      @stock = Hash.new(0)
      StockItem.on_hand.raw.each { |lot| @stock[[ lot.stockable_id, normalize(lot.unit) ]] += lot.quantity }
      @stocked_units = StockItem.on_hand.raw.each_with_object(Hash.new { |hash, key| hash[key] = Set.new }) { |lot, units| units[lot.stockable_id] << (lot.unit.presence || "a count") }

      # Named ingredients take their stock first; families draw on what is left.
      @needs.values.sort_by { |need| need[:family] ? 1 : 0 }.filter_map { |need| item_for(need) }.sort_by(&:name)
    end

    def need(component, servings, entry)
      return unless servings.positive?

      component.child_parts.includes(:child).each do |part|
        child_servings = servings * (Cooking::Meal.serving_unit?(part.unit) ? (part.quantity || 1) : 1)
        need(part.child, cover(part.child, child_servings), entry)
      end

      component.component_ingredients.includes(:ingredient, ingredient_family: :ingredients).each do |line|
        key = [ line.substitutable? ? :family : :ingredient, line.ingredient_family_id || line.ingredient_id, normalize(line.unit) ]
        need = @needs[key] ||= {
          family: line.substitutable?, ingredient: line.ingredient, family_record: line.ingredient_family,
          unit: line.unit.to_s.strip.presence, amount: 0, to_taste: false, meals: []
        }
        line.quantity ? need[:amount] += line.quantity * servings : need[:to_taste] = true
        need[:meals] << entry
      end
    end

    # Takes what stock has of the component, prepped or frozen, toward the
    # servings; returns the servings still to make.
    def cover(component, servings)
      covered = [ @prepped.fetch(component.id, 0), servings ].min
      @prepped[component.id] = @prepped.fetch(component.id, 0) - covered
      servings - covered
    end

    def item_for(need)
      ids = need[:family] ? need[:family_record].ingredients.map(&:id) : [ need[:ingredient].id ]
      name = need[:family] ? "any #{need[:family_record].name}" : need[:ingredient].name
      unit = normalize(need[:unit])

      if need[:amount].zero? && need[:to_taste]
        return if ids.any? { |id| @stocked_units[id].any? }

        return Item.new(name:, unit: nil, needed: 0, on_hand: 0, to_buy: 0, to_taste: true, meals: need[:meals])
      end

      on_hand = 0
      ids.each do |id|
        take = [ @stock[[ id, unit ]], need[:amount] - on_hand ].min
        next unless take.positive?

        @stock[[ id, unit ]] -= take
        on_hand += take
      end
      to_buy = need[:amount] - on_hand
      return unless to_buy.positive?

      to_buy = to_buy.ceil if unit.empty? # a count is bought whole

      other_units = ids.flat_map { |id| @stocked_units[id].to_a }.uniq.reject { |stocked| normalize(stocked == "a count" ? nil : stocked) == unit }
      note = "stock is in #{other_units.to_sentence}, not compared" if other_units.any?

      packs, pack = packs_for(need, to_buy)
      Item.new(name:, unit: need[:unit], needed: need[:amount], on_hand:, to_buy:, packs:, pack:, to_taste: false, meals: need[:meals], note:)
    end

    def packs_for(need, to_buy)
      ingredient = need[:ingredient]
      if ingredient&.pack_size&.positive? && normalize(ingredient.default_unit) == normalize(need[:unit])
        [ (to_buy / ingredient.pack_size).ceil, ingredient.pack_size ]
      else
        [ nil, nil ]
      end
    end

    def normalize(unit)
      unit.to_s.strip.downcase.singularize
    end
end
