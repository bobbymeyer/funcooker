require "test_helper"

class ComponentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @component = Component.create!(name: "Weeknight Chili", source_url: "https://food.test/chili")
    @component.steps.create!(position: 1, instructions: "Brown the beef.")
    @component.component_ingredients.create!(ingredient: Ingredient.create!(name: "ground beef"), quantity: 1.5, unit: "lb")
  end

  test "index and show" do
    get root_path
    assert_select "a", "Weeknight Chili"

    get component_path(@component)
    assert_select "h1", "Weeknight Chili"
    assert_select "td", "ground beef"
    assert_select "td.numeric", "1.5"
    assert_select "td", "Brown the beef."
  end

  test "create" do
    get new_component_path
    assert_response :success

    post components_path, params: { component: { name: "Rice", description: "", source_url: "" } }
    assert_redirected_to Component.find_by!(name: "Rice")
  end

  test "create without a name" do
    post components_path, params: { component: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "update" do
    get edit_component_path(@component)
    assert_response :success

    patch component_path(@component), params: { component: { name: "Chili" } }
    assert_redirected_to @component
    assert_equal "Chili", @component.reload.name
  end

  test "destroy takes its ingredient lines and steps with it" do
    assert_difference -> { Component.count } => -1, -> { Step.count } => -1, -> { ComponentIngredient.count } => -1 do
      delete component_path(@component)
    end
    assert_redirected_to components_path
    assert Ingredient.exists?(name: "ground beef"), "the ingredient itself stays"
  end

  test "a component used in another is not deleted" do
    ComponentPart.create!(parent: Component.create!(name: "Chili bowl"), child: @component)

    assert_no_difference -> { Component.count } do
      delete component_path(@component)
    end
    assert_redirected_to @component
    assert_match(/Cannot delete/, flash[:alert])
  end
end
