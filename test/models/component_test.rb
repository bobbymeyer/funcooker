require "test_helper"

class ComponentTest < ActiveSupport::TestCase
  setup do
    @dish = Component.create!(name: "tacos")
    @salsa = Component.create!(name: "salsa")
  end

  test "a component with nothing above it is a dish" do
    assert @dish.dish?
    assert_includes Component.dishes, @salsa
  end

  test "nesting a component makes it no longer a dish" do
    ComponentPart.create!(parent: @dish, child: @salsa)

    assert_not @salsa.dish?
    assert_equal [ @dish ], Component.dishes.to_a
  end

  test "parts cannot form a cycle" do
    ComponentPart.create!(parent: @dish, child: @salsa)

    assert_not ComponentPart.new(parent: @salsa, child: @dish).valid?
    assert_not ComponentPart.new(parent: @dish, child: @dish).valid?
  end
end
