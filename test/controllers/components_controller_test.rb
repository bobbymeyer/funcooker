require "test_helper"

class ComponentsControllerTest < ActionDispatch::IntegrationTest
  test "index and show" do
    component = Component.create!(name: "Weeknight Chili", source_url: "https://food.test/chili")
    component.steps.create!(position: 1, instructions: "Brown the beef.")
    component.component_ingredients.create!(ingredient: Ingredient.create!(name: "ground beef"), quantity: 1.5, unit: "lb")

    get root_path
    assert_select "a", "Weeknight Chili"

    get component_path(component)
    assert_select "h1", "Weeknight Chili"
    assert_select "td", "ground beef"
    assert_select "td.numeric", "1.5"
    assert_select "td", "Brown the beef."
  end
end
