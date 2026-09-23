require "test_helper"

class ShelfLifeJobTest < ActiveJob::TestCase
  setup do
    @component = Component.create!(name: "seasoned beef")
    @component.component_ingredients.create!(ingredient: Ingredient.create!(name: "ground beef"), quantity: 0.25, unit: "lb")
    @component.steps.create!(position: 1, instructions: "Brown the beef.")
  end

  test "stores the model's estimate and how it got there" do
    stub_llm days: 3, storage: "fridge, sealed", basis: "cooked meat"

    ShelfLifeJob.perform_now(@component)

    assert_equal [ 3, "fridge, sealed; cooked meat" ], [ @component.reload.shelf_life_days, @component.shelf_life_note ]
    assert_requested :post, LlmStubs::LLM_URL do |request|
      JSON.parse(request.body)["messages"].last["content"].include?("Made from: ground beef")
    end
  end

  test "leaves a shelf life already set, unless asked to overwrite" do
    @component.update!(shelf_life_days: 2)
    stub_llm days: 3, storage: "fridge", basis: "cooked meat"

    ShelfLifeJob.perform_now(@component)
    assert_equal 2, @component.reload.shelf_life_days

    ShelfLifeJob.perform_now(@component, overwrite: true)
    assert_equal 3, @component.reload.shelf_life_days
  end

  test "an answer that is not a positive number of days is not stored" do
    stub_llm days: 0, storage: "fridge", basis: "?"

    ShelfLifeJob.perform_now(@component)

    assert_nil @component.reload.shelf_life_days
  end

  test "setting it by hand drops the model's note" do
    @component.update!(shelf_life_days: 3, shelf_life_note: "fridge; cooked meat")

    @component.update!(shelf_life_days: 5)

    assert_nil @component.shelf_life_note
  end
end
