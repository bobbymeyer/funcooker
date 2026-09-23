require "test_helper"

class DecompositionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @alliums = IngredientFamily.create!(name: "alliums")
    @salsa = Component.create!(name: "salsa verde").tap do |salsa|
      salsa.component_ingredients.create!(ingredient: ingredient("tomatillo"), quantity: 2)
      salsa.component_ingredients.create!(ingredient: ingredient("jalapeño"), quantity: 0.5)
    end

    @tacos = Component.create!(name: "Beef tacos").tap do |tacos|
      tacos.component_ingredients.create!(ingredient: ingredient("corn tortilla"), quantity: 2)          # i1
      tacos.component_ingredients.create!(ingredient: ingredient("tomatillo"), quantity: 2)              # i2
      tacos.component_ingredients.create!(ingredient: ingredient("jalapeño"), quantity: 0.5)             # i3
      tacos.component_ingredients.create!(ingredient_family: @alliums, quantity: 0.25, unit: "cup")      # i4
      tacos.component_ingredients.create!(ingredient: ingredient("ground beef"), quantity: 0.25, unit: "lb") # i5
      tacos.component_ingredients.create!(ingredient: ingredient("salt"), note: "to taste")              # i6
      tacos.steps.create!(position: 1, instructions: "Blend the tomatillos and jalapeño.")
      tacos.steps.create!(position: 2, instructions: "Brown the beef with the onion and salt.")
      tacos.steps.create!(position: 3, instructions: "Fill the tortillas.")
    end
  end

  PLAN = {
    components: [
      { name: "salsa verde", existing: "salsa verde", servings: 1,
        ingredients: [ { line: "i2", amount: nil, unit: nil, note: nil }, { line: "i3", amount: nil, unit: nil, note: nil } ], steps: [] },
      { name: "seasoned beef", existing: nil, servings: 1,
        ingredients: [
          { line: "i5", amount: 0.25, unit: "lb", note: nil },
          { line: "i4", amount: 0.25, unit: "cup", note: "diced" },
          { line: "i6", amount: nil, unit: nil, note: nil }
        ],
        steps: [ { instructions: "Brown the beef with the onion and salt.", phase: "prep", mode: "active", duration_minutes: 12 } ] }
    ],
    ingredients: [ { line: "i1", amount: 2, unit: nil, note: nil } ],
    steps: [
      { instructions: "Warm the tortillas, fill with seasoned beef and top with salsa verde.", phase: "plate", mode: "active", duration_minutes: 5,
        uses: [ "seasoned beef", "salsa verde", "i1" ] }
    ]
  }.freeze

  test "a recipe is rewritten to use existing and new components" do
    stub_llm PLAN

    decomposition = @tacos.decompositions.create!
    decomposition.process

    assert decomposition.succeeded?, decomposition.error
    @tacos.reload

    salsa_part, beef_part = @tacos.child_parts.order(:id)
    assert_equal @salsa, salsa_part.child, "the existing salsa verde is reused, not copied"
    assert_equal [ 1, "serving" ], [ salsa_part.quantity, salsa_part.unit ]

    beef = beef_part.child
    assert_equal "seasoned beef", beef.name
    assert_equal [ "ground beef", "alliums", "salt" ], beef.component_ingredients.order(:id).map { |line| (line.ingredient || line.ingredient_family).name }
    assert_equal [ 0.25, "cup", "diced" ], beef.component_ingredients.find_by!(ingredient_family: @alliums).then { |line| [ line.quantity, line.unit, line.note ] },
      "a family slot keeps its family"
    assert_equal "to taste", beef.component_ingredients.find_by!(ingredient: Ingredient.find_by!(name: "salt")).note, "an unchanged line keeps its note"
    assert_equal [ [ "prep", "active", 12 ] ], beef.steps.map { |step| [ step.phase, step.mode, step.duration_minutes ] }
    assert_not beef.dish?

    assert_equal [ "corn tortilla" ], @tacos.component_ingredients.map { |line| line.ingredient.name }, "tomatillo and jalapeño are covered by the salsa, not left on the dish"
    step = @tacos.steps.sole
    assert_equal [ "plate", "active", 5 ], [ step.phase, step.mode, step.duration_minutes ]
    assert_equal [ step, step ], [ salsa_part.step, beef_part.step ]
    assert_equal step, @tacos.component_ingredients.sole.step
    assert @tacos.dish?
  end

  test "the original ingredients and steps are kept" do
    stub_llm PLAN

    decomposition = @tacos.decompositions.create!
    decomposition.process

    assert_equal 6, decomposition.original["ingredients"].size
    assert_equal "Blend the tomatillos and jalapeño.", decomposition.original["steps"].first["instructions"]
  end

  test "a line the model forgets stays on the dish" do
    stub_llm PLAN.merge(ingredients: [])

    decomposition = @tacos.decompositions.create!
    decomposition.process

    assert_equal [ "corn tortilla" ], @tacos.reload.component_ingredients.map { |line| line.ingredient.name }
  end

  test "the model is given line ids and the known components, and can only reuse those" do
    stub_llm PLAN

    @tacos.decompositions.create!.process

    assert_requested :post, LlmStubs::LLM_URL do |request|
      body = JSON.parse(request.body)
      system, user = body["messages"].map { |message| message["content"] }
      schema = body.dig("response_format", "json_schema", "schema")
      existing = schema.dig("properties", "components", "items", "properties", "existing", "anyOf", 0, "enum")
      line_ids = schema.dig("properties", "ingredients", "items", "properties", "line", "enum")

      user.include?("i4: 0.25 cup any alliums") && user.include?("i6: salt, to taste") &&
        system.include?("- salsa verde: tomatillo, jalapeño") &&
        existing == [ "salsa verde" ] && line_ids == %w[ i1 i2 i3 i4 i5 i6 ]
    end
  end

  test "a recipe the model finds no components in fails, and is left as it was" do
    stub_llm components: [], ingredients: [], steps: []

    decomposition = @tacos.decompositions.create!
    decomposition.process

    assert decomposition.failed?
    assert_match "Nothing to break out", decomposition.error
    assert_equal 6, @tacos.component_ingredients.count
    assert_equal 3, @tacos.steps.count
  end

  test "a failure part way through changes nothing" do
    stub_llm PLAN.merge(components: [ PLAN[:components].first.merge(existing: "pico de gallo") ])

    decomposition = @tacos.decompositions.create!
    decomposition.process

    assert decomposition.failed?
    assert_match "not in the library: pico de gallo", decomposition.error
    assert_equal 6, @tacos.component_ingredients.count
    assert_empty @tacos.child_parts
  end

  test "a component and its ancestors are never offered for reuse" do
    plate = Component.create!(name: "taco plate")
    ComponentPart.create!(parent: plate, child: @tacos)
    stub_llm PLAN

    @tacos.decompositions.create!.process

    assert_requested :post, LlmStubs::LLM_URL do |request|
      system = JSON.parse(request.body)["messages"].first["content"]
      !system.include?("- taco plate") && !system.include?("- Beef tacos")
    end
  end

  test "only a recipe not yet decomposed can be" do
    stub_llm PLAN
    @tacos.decompositions.create!.process

    assert_not @tacos.reload.decomposable?
    assert_not @tacos.decompositions.new.valid?
  end

  test "creating one enqueues it" do
    assert_enqueued_with(job: DecompositionJob) { @tacos.decompositions.create! }
  end

  private
    def ingredient(name) = Ingredient.find_or_create_by!(name:)
end
