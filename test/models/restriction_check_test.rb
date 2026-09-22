require "test_helper"

class RestrictionCheckTest < ActiveSupport::TestCase
  setup do
    @kid = HouseholdMember.create!(name: "kid")
    @alliums = IngredientFamily.create!(name: "alliums")
    @shallot = Ingredient.create!(name: "shallot", ingredient_family: @alliums)
    @onion = Ingredient.create!(name: "red onion", ingredient_family: @alliums)
    @dish = Component.create!(name: "tacos")
    @salsa = Component.create!(name: "salsa")
    ComponentPart.create!(parent: @dish, child: @salsa)
  end

  test "a restricted locked ingredient in a nested component violates" do
    @salsa.component_ingredients.create!(ingredient: @onion)
    restrict @onion

    assert @dish.restricted_for?(@kid)
  end

  test "a family slot does not violate while an unrestricted member remains" do
    @salsa.component_ingredients.create!(ingredient_family: @alliums)
    restrict @onion

    assert_not @dish.restricted_for?(@kid)
  end

  test "a family slot violates when every member is restricted" do
    @salsa.component_ingredients.create!(ingredient_family: @alliums)
    restrict @onion
    restrict @shallot

    assert @dish.restricted_for?(@kid)
  end

  test "a restricted family violates a locked ingredient in it" do
    @salsa.component_ingredients.create!(ingredient: @shallot)
    restrict @alliums

    assert @dish.restricted_for?(@kid)
  end

  test "a restricted component violates any dish containing it" do
    restrict @salsa

    assert @dish.restricted_for?(@kid)
  end

  test "preferences never violate" do
    @salsa.component_ingredients.create!(ingredient: @onion)
    @kid.food_needs.create!(subject: @onion, tier: :preference)

    assert_not @dish.restricted_for?(@kid)
  end

  test "the scheduler's candidates exclude restricted dishes" do
    @salsa.component_ingredients.create!(ingredient: @onion)
    restrict @onion
    soup = Component.create!(name: "soup")

    assert_equal [ soup ], Component.schedulable_for([ @kid ])
  end

  private
    def restrict(subject)
      @kid.food_needs.create!(subject: subject, tier: :restriction)
    end
end
