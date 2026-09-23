require "test_helper"

class Components::PartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tacos = Component.create!(name: "Tacos")
    @salsa = Component.create!(name: "Salsa")
  end

  test "add a component" do
    get new_component_part_path(@tacos)
    assert_select "option", "Salsa"
    assert_select "option", text: "Tacos", count: 0

    post component_parts_path(@tacos), params: { component_part: { child_id: @salsa.id, quantity: "1", unit: "serving" } }

    assert_redirected_to @tacos
    assert_equal [ @salsa ], @tacos.children
  end

  test "a component that would contain itself is refused" do
    ComponentPart.create!(parent: @tacos, child: @salsa)

    post component_parts_path(@salsa), params: { component_part: { child_id: @tacos.id } }
    assert_response :unprocessable_entity
  end

  test "update and remove" do
    part = ComponentPart.create!(parent: @tacos, child: @salsa, quantity: 1, unit: "serving")

    get edit_part_path(part)
    assert_response :success
    patch part_path(part), params: { component_part: { quantity: "0.5" } }
    assert_equal 0.5, part.reload.quantity

    delete part_path(part)
    assert_redirected_to @tacos
    assert_empty @tacos.children
    assert Component.exists?(@salsa.id), "removing a part keeps the component"
  end
end
