require "test_helper"

class DecompositionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @component = Component.create!(name: "Beef tacos")
    @component.component_ingredients.create!(ingredient: Ingredient.create!(name: "ground beef"), quantity: 0.25, unit: "lb")
  end

  test "the button shows on a recipe that can be decomposed" do
    get component_path(@component)
    assert_select "form[action='#{component_decompositions_path(@component)}'] button", "Decompose"
  end

  test "decomposing enqueues and shows progress" do
    assert_enqueued_jobs 1, only: DecompositionJob do
      post component_decompositions_path(@component)
    end

    assert_redirected_to Decomposition.last
    follow_redirect!
    assert_select "p", /Breaking it into components/
  end

  test "an already decomposed recipe explains why not" do
    ComponentPart.create!(parent: @component, child: Component.create!(name: "salsa"))

    get component_path(@component)
    assert_select "button", text: "Decompose", count: 0

    post component_decompositions_path(@component)
    assert_redirected_to @component
    assert_equal "Component is already made of other components", flash[:alert]
  end

  test "a finished decomposition goes to the recipe" do
    decomposition = @component.decompositions.create!(status: :succeeded)

    get decomposition_path(decomposition)
    assert_redirected_to @component
  end
end
