require "test_helper"

class Components::IngredientLinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @component = Component.create!(name: "Chili")
    @line = @component.component_ingredients.create!(ingredient: Ingredient.create!(name: "ground beef"), quantity: 1, unit: "lb")
  end

  test "add an ingredient by name, creating it when new" do
    get new_component_ingredient_line_path(@component)
    assert_response :success

    post component_ingredient_lines_path(@component), params: { component_ingredient: { ingredient_name: "Kidney Bean", quantity: "0.5", unit: "cup", note: "drained" } }

    assert_redirected_to @component
    line = @component.component_ingredients.last
    assert_equal [ "kidney bean", 0.5, "cup", "drained" ], [ line.ingredient.name, line.quantity, line.unit, line.note ]
  end

  test "add a family slot" do
    alliums = IngredientFamily.create!(name: "alliums")

    post component_ingredient_lines_path(@component), params: { component_ingredient: { ingredient_name: "", ingredient_family_id: alliums.id, quantity: "0.25", unit: "cup" } }

    assert_redirected_to @component
    assert_equal alliums, @component.component_ingredients.last.ingredient_family
  end

  test "neither an ingredient nor a family is refused" do
    post component_ingredient_lines_path(@component), params: { component_ingredient: { ingredient_name: "", ingredient_family_id: "", quantity: "1" } }
    assert_response :unprocessable_entity
  end

  test "update" do
    get edit_ingredient_line_path(@line)
    assert_response :success

    patch ingredient_line_path(@line), params: { component_ingredient: { quantity: "2" } }
    assert_redirected_to @component
    assert_equal 2, @line.reload.quantity
  end

  test "destroy" do
    delete ingredient_line_path(@line)
    assert_redirected_to @component
    assert_not ComponentIngredient.exists?(@line.id)
  end
end
