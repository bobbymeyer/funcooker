require "test_helper"

class IngredientFamiliesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alliums = IngredientFamily.create!(name: "alliums")
    @onion = Ingredient.create!(name: "red onion", ingredient_family: @alliums)
  end

  test "index lists members" do
    get ingredient_families_path
    assert_select "td", "red onion"
  end

  test "create, update, destroy" do
    post ingredient_families_path, params: { ingredient_family: { name: "greens" } }
    assert_redirected_to ingredient_families_path

    get edit_ingredient_family_path(@alliums)
    assert_response :success
    patch ingredient_family_path(@alliums), params: { ingredient_family: { name: "onions" } }
    assert_equal "onions", @alliums.reload.name

    delete ingredient_family_path(@alliums)
    assert_not IngredientFamily.exists?(@alliums.id)
    assert_nil @onion.reload.ingredient_family, "its ingredients stay, outside any family"
  end

  test "a family used as a recipe slot is not deleted" do
    Component.create!(name: "Salsa").component_ingredients.create!(ingredient_family: @alliums)

    delete ingredient_family_path(@alliums)
    assert IngredientFamily.exists?(@alliums.id)
  end
end
