# What to take out of the freezer for the meals ahead, and when.
#
# Meals are taken in date order, as cooking will take them: a dish, or a
# component inside it, is drawn from stock when prepped and frozen servings
# together cover it, and cooked otherwise. The fridge is used first; what it
# is short of comes out of the freezer, soonest-expiring lot first. Each such
# draw is a thaw, due the evening before the meal, or now for a meal today.
class ThawPlan
  Thaw = Struct.new(:component, :servings, :lot, :entry, keyword_init: true) do
    # The day to take it out: the day before the meal, or the day itself.
    def by
      [ entry.served_on - 1, Date.current ].max
    end

    # When the reminder falls due: the evening of that day, in the app's time
    # zone, or now if that has passed.
    def due_at
      [ by.in_time_zone.change(hour: EVENING_HOUR), Time.current ].max
    end

    def title
      "Thaw #{component.name}, #{format_servings}, for #{entry.served_on == Date.current ? "today" : entry.served_on.strftime("%A")}"
    end

    def notes
      "#{entry.dish.name}, #{entry.served_on.strftime("%a %b %-d")} #{entry.meal_slot}. From the freezer lot keeping until #{lot.expires_on&.strftime("%b %-d") || "no date"}."
    end

    def to_reminder
      { title:, notes:, due: due_at.iso8601 }
    end

    private
      def format_servings
        amount = servings.round(3).to_s("F").sub(/\.0\z/, "")
        "#{amount} #{"serving".pluralize(servings == 1 ? 1 : 2)}"
      end
  end

  DEFAULT_DAYS = 2
  EVENING_HOUR = 18

  attr_reader :from, :days

  def initialize(from: Date.current, days: DEFAULT_DAYS)
    @from, @days = from, days
  end

  def entries
    @entries ||= ScheduleEntry.active.planned.where(served_on: from...(from + days)).includes(:dish, :diners).chronological.to_a
  end

  def thaws
    @thaws ||= build
  end

  # Thaws due by the end of the day: tonight's job.
  def due(on = Date.current)
    thaws.select { |thaw| thaw.by <= on }
  end

  private
    def build
      @fridge = pool(:prepped)
      @freezer = StockItem.on_hand.freezer.first_out.select { |lot| Cooking::Meal.serving_unit?(lot.unit) }.group_by(&:stockable_id)
      @left = @freezer.transform_values { |lots| lots.to_h { |lot| [ lot.id, lot.quantity ] } }
      @thaws = []
      entries.each { |entry| take(entry.dish, entry.servings, entry) }
      @thaws
    end

    def pool(kind)
      StockItem.on_hand.where(kind:).select { |lot| Cooking::Meal.serving_unit?(lot.unit) }.group_by(&:stockable_id).transform_values { |lots| lots.sum(&:quantity) }
    end

    # Draws the component from stock if stock covers it; otherwise it is
    # cooked, and what goes inside it is taken in turn.
    def take(component, servings, entry)
      return unless servings.positive?

      fridge = @fridge.fetch(component.id, 0)
      frozen = @left.fetch(component.id, {}).values.sum

      if fridge + frozen >= servings
        from_fridge = [ fridge, servings ].min
        @fridge[component.id] = fridge - from_fridge
        thaw(component, servings - from_fridge, entry)
      else
        component.child_parts.includes(:child).each do |part|
          take(part.child, servings * (Cooking::Meal.serving_unit?(part.unit) ? (part.quantity || 1) : 1), entry)
        end
      end
    end

    def thaw(component, servings, entry)
      @freezer.fetch(component.id, []).each do |lot|
        break unless servings.positive?

        amount = [ @left[component.id][lot.id], servings ].min
        next unless amount.positive?

        @left[component.id][lot.id] -= amount
        servings -= amount
        @thaws << Thaw.new(component:, servings: amount, lot:, entry:)
      end
    end
end
