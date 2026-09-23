# What a component is made of, at any depth: the components inside it, the
# ingredients it names outright, and the families it leaves open. The
# scheduler reads dishes through this, to score them against stock and
# against what people like.
class DishContents
  attr_reader :component_ids, :ingredient_ids, :family_ids

  def initialize(component)
    @root = component
    @component_ids, @ingredient_ids, @family_ids = Set.new, Set.new, Set.new
    @lines = []
    walk(component)
  end

  # Whether the dish contains a food-need subject.
  def include?(subject)
    case subject
    when Component then @component_ids.include?(subject.id)
    when Ingredient then @ingredient_ids.include?(subject.id) || @family_ids.include?(subject.ingredient_family_id)
    when IngredientFamily then @family_ids.include?(subject.id) || @lines.any? { |line| line.ingredient&.ingredient_family_id == subject.id }
    else false
    end
  end

  # How much of the dish could be made from stock on hand, 0 to 1. A
  # component on hand covers everything inside it; a family slot is covered by
  # any of its members.
  def coverage(on_hand)
    covered, total = count_covered(@root, on_hand)
    total.zero? ? 0 : covered.fdiv(total)
  end

  # Whether this dish would draw on a stock lot: a component inside it, or an
  # ingredient it names or leaves open through a family.
  def draws_on?(lot)
    if lot.stockable_type == "Component"
      @component_ids.include?(lot.stockable_id)
    else
      usable_ingredient_ids.include?(lot.stockable_id)
    end
  end

  private
    def usable_ingredient_ids
      @usable_ingredient_ids ||= @ingredient_ids | @lines.select(&:substitutable?).flat_map { |line| line.ingredient_family.ingredients.map(&:id) }
    end

    def walk(component)
      @component_ids << component.id
      component.component_ingredients.each do |line|
        @lines << line
        line.substitutable? ? @family_ids << line.ingredient_family_id : @ingredient_ids << line.ingredient_id
      end
      component.children.each { |child| walk(child) }
    end

    def count_covered(component, on_hand)
      return [ 1, 1 ] if component != @root && on_hand.component_ids.include?(component.id)

      covered = component.component_ingredients.count { |line| line_on_hand?(line, on_hand) }
      total = component.component_ingredients.size
      component.children.each do |child|
        c, t = count_covered(child, on_hand)
        covered += c
        total += t
      end
      [ covered, total ]
    end

    def line_on_hand?(line, on_hand)
      if line.substitutable?
        line.ingredient_family.ingredients.any? { |ingredient| on_hand.ingredient_ids.include?(ingredient.id) }
      else
        on_hand.ingredient_ids.include?(line.ingredient_id)
      end
    end
end
