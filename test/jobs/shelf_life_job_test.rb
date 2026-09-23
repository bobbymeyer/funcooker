require "test_helper"

class ShelfLifeJobTest < ActiveJob::TestCase
  setup do
    @component = Component.create!(name: "seasoned beef")
    @component.component_ingredients.create!(ingredient: Ingredient.create!(name: "ground beef"), quantity: 0.25, unit: "lb")
    @component.steps.create!(position: 1, instructions: "Brown the beef.")
  end

  test "stores the model's estimates and how it got there" do
    stub_llm days: 3, storage: "fridge, sealed", basis: "cooked meat", freezer_days: 60, freezer_basis: "cooked meat, sealed"

    ShelfLifeJob.perform_now(@component)

    assert_equal [ 3, "fridge, sealed; cooked meat" ], [ @component.reload.shelf_life_days, @component.shelf_life_note ]
    assert_equal [ 60, "cooked meat, sealed" ], [ @component.freezer_life_days, @component.freezer_life_note ]
    assert @component.freezable?
    assert_requested :post, LlmStubs::LLM_URL do |request|
      JSON.parse(request.body)["messages"].last["content"].include?("Made from: ground beef")
    end
  end

  test "fills in only what is blank, unless asked to overwrite" do
    @component.update!(shelf_life_days: 2)
    stub_llm days: 3, storage: "fridge", basis: "cooked meat", freezer_days: 60, freezer_basis: "cooked meat"

    ShelfLifeJob.perform_now(@component)
    assert_equal [ 2, 60 ], [ @component.reload.shelf_life_days, @component.freezer_life_days ]

    ShelfLifeJob.perform_now(@component, overwrite: true)
    assert_equal 3, @component.reload.shelf_life_days
  end

  test "0 days frozen means it does not freeze well" do
    stub_llm days: 2, storage: "fridge", basis: "dressed salad", freezer_days: 0, freezer_basis: "leaves go limp"

    ShelfLifeJob.perform_now(@component)

    assert_equal 0, @component.reload.freezer_life_days
    assert_not @component.freezable?
  end

  test "an answer that is not a positive number of days, or leaves out the freezer, is not stored" do
    stub_llm({ days: 0, storage: "fridge", basis: "?", freezer_days: 30, freezer_basis: "?" }, { days: 3, storage: "fridge", basis: "?" })

    ShelfLifeJob.perform_now(@component)
    ShelfLifeJob.perform_now(@component)

    assert_equal [ nil, nil ], [ @component.reload.shelf_life_days, @component.freezer_life_days ]
  end

  test "setting it by hand drops the model's note" do
    @component.update!(shelf_life_days: 3, shelf_life_note: "fridge; cooked meat")

    @component.update!(shelf_life_days: 5)

    assert_nil @component.shelf_life_note

    @component.update!(freezer_life_days: 60, freezer_life_note: "cooked meat")
    @component.update!(freezer_life_days: 30)

    assert_nil @component.freezer_life_note
  end
end
