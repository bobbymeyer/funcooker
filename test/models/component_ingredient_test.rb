require "test_helper"

class ComponentIngredientTest < ActiveSupport::TestCase
  setup do
    @component = Component.create!(name: "salsa")
    @alliums = IngredientFamily.create!(name: "alliums")
    @onion = Ingredient.create!(name: "red onion", ingredient_family: @alliums)
  end

  test "references a locked ingredient or a family" do
    assert ComponentIngredient.new(component: @component, ingredient: @onion).valid?
    assert ComponentIngredient.new(component: @component, ingredient_family: @alliums).valid?
  end

  test "rejects both or neither" do
    assert_not ComponentIngredient.new(component: @component).valid?
    assert_not ComponentIngredient.new(component: @component, ingredient: @onion, ingredient_family: @alliums).valid?
  end
end
