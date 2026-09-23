module HouseholdMembersHelper
  def food_need_subject_options(selected)
    grouped_options_for_select({
      "Ingredients" => Ingredient.order(:name).map { |ingredient| [ ingredient.name, "Ingredient:#{ingredient.id}" ] },
      "Families" => IngredientFamily.order(:name).map { |family| [ "any #{family.name}", "IngredientFamily:#{family.id}" ] },
      "Components" => Component.order(:name).map { |component| [ component.name, "Component:#{component.id}" ] }
    }, selected)
  end
end
