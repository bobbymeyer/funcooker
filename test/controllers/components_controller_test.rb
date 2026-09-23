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

  test "filter for dishes, or for the parts of dishes" do
    salsa = Component.create!(name: "salsa")
    ComponentPart.create!(parent: @component, child: salsa)

    get components_path(show: "dishes")
    assert_select "td a", "Weeknight Chili"
    assert_select "td a", text: "salsa", count: 0
    assert_select ".filter a[aria-current=true]", "Dishes"

    get components_path(show: "parts")
    assert_select "td a", "salsa"
    assert_select "td a", text: "Weeknight Chili", count: 0
  end

  test "estimate one shelf life, or every missing one" do
    Component.create!(name: "rice", shelf_life_days: 4)

    assert_enqueued_jobs 1, only: ShelfLifeJob do
      post estimate_shelf_life_component_path(@component)
    end
    assert_redirected_to @component

    assert_enqueued_jobs 1, only: ShelfLifeJob do
      post estimate_shelf_lives_components_path
    end
    assert_equal "Estimating 1 shelf life.", flash[:notice]
  end

  test "a borderline decomposition shows its caveats and asks" do
    decomposition = @component.decompositions.create!
    decomposition.update!(status: :awaiting, reason: "The beef could be braised apart.", caveats: [ "The sauce loses the fond." ],
      plan: { components: [ { name: "braised beef", existing: nil } ] }, line_ids: @component.component_ingredients.ids)

    get component_path(@component)

    assert_select ".judgement li", "The sauce loses the fond."
    assert_select ".judgement p", /It would break out: braised beef/
    assert_select "button", "Decompose anyway"
    assert_select "button", text: "Decompose", count: 0

    post dismiss_decomposition_path(decomposition)
    assert decomposition.reload.dismissed?
  end

  test "a declined decomposition says why" do
    @component.decompositions.create!.update!(status: :declined, reason: "It all cooks in one pot.")

    get component_path(@component)
    assert_select ".judgement p", /Not decomposed.\s+It all cooks in one pot./
  end
end
