# How a scheduled meal gets cooked: the components inside its dish that are
# already prepped in stock are drawn from stock; the rest are cooked now,
# innermost first, and the dish last.
class Cooking::Meal
  SERVING_UNITS = [ nil, "", "serving" ].freeze

  # Yields every component inside a dish, at any depth, with the servings the
  # dish needs of it. A part counted in servings scales; any other unit is
  # taken as one serving of the part per serving of the dish.
  def self.walk(component, servings, &block)
    component.child_parts.includes(:child).each do |part|
      child_servings = servings * (serving_unit?(part.unit) ? (part.quantity || 1) : 1)
      yield part.child, child_servings
      walk(part.child, child_servings, &block)
    end
  end

  def self.serving_unit?(unit)
    unit.to_s.strip.downcase.singularize.in?(SERVING_UNITS)
  end

  def self.prepped_servings(component)
    StockItem.on_hand.prepped.where(stockable: component).select { |lot| serving_unit?(lot.unit) }.sum(&:quantity)
  end

  def initialize(entry)
    @entry = entry
  end

  # [[component, servings]] to cook now, innermost first, ending with the dish.
  def cook_now
    plan(@entry.dish, @entry.servings) + [ [ @entry.dish, @entry.servings ] ]
  end

  private
    def plan(component, servings)
      component.child_parts.includes(:child).flat_map do |part|
        child_servings = servings * (self.class.serving_unit?(part.unit) ? (part.quantity || 1) : 1)
        if covered?(part.child, child_servings)
          []
        else
          plan(part.child, child_servings) + [ [ part.child, child_servings ] ]
        end
      end
    end

    def covered?(component, servings)
      self.class.prepped_servings(component) >= servings
    end
end
