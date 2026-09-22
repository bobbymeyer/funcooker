# Whether serving a component would violate one member's restrictions.
#
# A locked ingredient violates if it, or its family, is restricted. A family slot
# violates only if the family is restricted or every ingredient in it is, since
# otherwise an unrestricted member of the family can be substituted.
class RestrictionCheck
  def initialize(member)
    needs = member.food_needs.restriction
    @components = ids_for(needs, "Component")
    @ingredients = ids_for(needs, "Ingredient")
    @families = ids_for(needs, "IngredientFamily")
  end

  def violated_by?(component)
    component.self_and_descendants.any? do |c|
      @components.include?(c.id) || c.component_ingredients.any? { |ci| violated_by_slot?(ci) }
    end
  end

  private
    def ids_for(needs, type)
      needs.where(subject_type: type).pluck(:subject_id).to_set
    end

    def violated_by_slot?(component_ingredient)
      if component_ingredient.substitutable?
        family = component_ingredient.ingredient_family
        @families.include?(family.id) || family.ingredients.all? { |i| @ingredients.include?(i.id) }
      else
        ingredient = component_ingredient.ingredient
        @ingredients.include?(ingredient.id) || @families.include?(ingredient.ingredient_family_id)
      end
    end
end
