require "test_helper"

class IngredientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alliums = IngredientFamily.create!(name: "alliums")
    @onion = Ingredient.create!(name: "red onion")
  end

  test "index" do
    get ingredients_path
    assert_select "td", "red onion"
  end

  test "create" do
    get new_ingredient_path
    assert_response :success

    post ingredients_path, params: { ingredient: { name: "shallot", category: "produce", default_unit: "each", ingredient_family_id: @alliums.id } }
    assert_redirected_to ingredients_path
    assert_equal @alliums, Ingredient.find_by!(name: "shallot").ingredient_family
  end

  test "a duplicate name is refused" do
    post ingredients_path, params: { ingredient: { name: "red onion" } }
    assert_response :unprocessable_entity
  end

  test "update" do
    get edit_ingredient_path(@onion)
    assert_response :success

    patch ingredient_path(@onion), params: { ingredient: { ingredient_family_id: @alliums.id } }
    assert_redirected_to ingredients_path
    assert_equal @alliums, @onion.reload.ingredient_family
  end

  test "destroy" do
    delete ingredient_path(@onion)
    assert_redirected_to ingredients_path
    assert_not Ingredient.exists?(@onion.id)
  end

  test "an ingredient in a recipe or in stock is not deleted" do
    Component.create!(name: "Salsa").component_ingredients.create!(ingredient: @onion)

    delete ingredient_path(@onion)
    assert Ingredient.exists?(@onion.id)
    assert_match "red onion was not deleted", flash[:alert]
  end
end
