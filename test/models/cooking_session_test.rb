require "test_helper"

class CookingSessionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @bobby = HouseholdMember.create!(name: "Bobby")
    @kid = HouseholdMember.create!(name: "kid", portion: 0.5)

    @beef = Ingredient.create!(name: "ground beef")
    @tomatillo = Ingredient.create!(name: "tomatillo")
    @tortilla = Ingredient.create!(name: "corn tortilla")

    @salsa = Component.create!(name: "salsa verde", shelf_life_days: 5)
    @salsa.component_ingredients.create!(ingredient: @tomatillo, quantity: 2)
    @blend = @salsa.steps.create!(position: 1, instructions: "Blend.", mode: :active, duration_minutes: 5)

    @beef_filling = Component.create!(name: "seasoned beef")
    @beef_filling.component_ingredients.create!(ingredient: @beef, quantity: 0.25, unit: "lb")
    @brown = @beef_filling.steps.create!(position: 1, instructions: "Brown the beef.", mode: :active, duration_minutes: 10)
    @rest = @beef_filling.steps.create!(position: 2, instructions: "Let it rest.", mode: :passive, duration_minutes: 20)

    @tacos = Component.create!(name: "tacos")
    @tacos.component_ingredients.create!(ingredient: @tortilla, quantity: 2)
    ComponentPart.create!(parent: @tacos, child: @salsa, quantity: 1, unit: "serving")
    ComponentPart.create!(parent: @tacos, child: @beef_filling, quantity: 1, unit: "serving")
    @assemble = @tacos.steps.create!(position: 1, instructions: "Fill the tortillas.", phase: :plate)

    @entry = ScheduleEntry.create!(served_on: Date.current + 1, dish: @tacos)
  end

  test "prep suggests the components the planned meals need, less what is prepped" do
    lot = StockItem.create!(stockable: @salsa, kind: :prepped, quantity: 1, unit: "serving")

    suggestions = Cooking::PrepPlan.new.suggestions.to_h

    assert_equal 1.5, suggestions[@beef_filling], "Bobby and a half-portion kid"
    assert_equal 0.5, suggestions[@salsa], "1.5 needed, 1 on hand"
    assert_not suggestions.key?(@tacos), "the dish itself is cooked on the day"
    assert lot
  end

  test "a prep session is ordered by the model, keeping each component's steps in order" do
    session = CookingSession.prep!([ { component: @beef_filling, servings: 2 }, { component: @salsa, servings: 3 } ])
    brown, rest, blend = session.tasks.map(&:id)
    stub_llm clusters: [
      { label: "stovetop", steps: [ "t#{rest}", "t#{brown}" ] },
      { label: "blender", steps: [ "t#{blend}", "t#{blend}", "t999" ] }
    ]

    session.sequence

    assert session.ready?
    assert_equal [ "Brown the beef.", "Let it rest.", "Blend." ], session.tasks.reload.map(&:instructions), "rest cannot come before brown"
    assert_equal [ "stovetop", "stovetop", "blender" ], session.tasks.map(&:cluster)
    assert_equal [ 2, 2, 3 ], session.tasks.map(&:servings)
  end

  test "a prep session the model cannot order says why, and can be cooked in recipe order" do
    session = CookingSession.prep!([ { component: @salsa, servings: 1 } ])
    stub_request(:post, LlmStubs::LLM_URL).to_return(status: 503, body: "loading")

    session.sequence
    assert session.failed?
    assert_match "503", session.error

    session.sequence_in_recipe_order!
    assert session.ready?
  end

  test "creating a prep session enqueues its sequencing" do
    assert_enqueued_with(job: CookingSequenceJob) { CookingSession.prep!([ { component: @salsa, servings: 1 } ]) }
  end

  test "steps are walked one at a time, with timed passive steps running alongside" do
    session = CookingSession.prep!([ { component: @beef_filling, servings: 1 } ])
    session.sequence_in_recipe_order!
    brown, rest = session.tasks

    assert_equal brown, session.current_task
    brown.complete!
    assert_equal rest, session.reload.current_task
    assert rest.timed?

    rest.start!
    session.reload
    assert_nil session.current_task
    assert_equal [ rest ], session.running_tasks
    assert_in_delta 20.minutes.from_now, rest.ends_at, 5
    assert_not session.all_done?

    rest.complete!
    assert session.reload.all_done?
  end

  test "a step shows its ingredients scaled to the servings" do
    session = CookingSession.prep!([ { component: @beef_filling, servings: 4 } ])

    line, amount = session.tasks.first.ingredient_lines.sole
    assert_equal [ @beef, 1 ], [ line.ingredient, amount ]
  end

  test "finishing a prep session stocks each batch and draws its ingredients" do
    beef_lot = StockItem.create!(stockable: @beef, kind: :raw, quantity: 1, unit: "lb", expires_on: Date.current + 2)
    StockItem.create!(stockable: @tomatillo, kind: :raw, quantity: 10, unit: "each")
    session = CookingSession.prep!([ { component: @beef_filling, servings: 2 }, { component: @salsa, servings: 3 } ])
    session.sequence_in_recipe_order!
    session.tasks.each(&:complete!)

    session.reload.finish!

    assert session.done?
    assert_equal 0.5, beef_lot.reload.quantity, "0.25 lb x 2 servings"
    assert_equal [ -0.5, "step_consumption" ], beef_lot.stock_transactions.order(:id).last.then { |t| [ t.delta, t.source ] }

    salsa_lot = StockItem.prepped.find_by!(stockable: @salsa)
    assert_equal [ 3, "serving", Date.current + 5 ], [ salsa_lot.quantity, salsa_lot.unit, salsa_lot.expires_on ]
    assert_equal "step_production", salsa_lot.stock_transactions.sole.source
    assert_match "tomatillo: not drawn, the recipe measures in a count and stock in each", session.stock_notes
  end

  test "a meal with its components prepped cooks only the dish" do
    StockItem.create!(stockable: @salsa, kind: :prepped, quantity: 5, unit: "serving")
    StockItem.create!(stockable: @beef_filling, kind: :prepped, quantity: 5, unit: "serving")

    session = CookingSession.plate!(@entry)

    assert_equal [ "Fill the tortillas." ], session.tasks.map(&:instructions)
    assert_equal 1.5, session.tasks.first.servings
  end

  test "a meal cooks what is not prepped first, then the dish" do
    StockItem.create!(stockable: @salsa, kind: :prepped, quantity: 5, unit: "serving")

    session = CookingSession.plate!(@entry)

    assert_equal [ "Brown the beef.", "Let it rest.", "Fill the tortillas." ], session.tasks.map(&:instructions)
  end

  test "finishing a meal draws what it used and marks it served" do
    salsa_lot = StockItem.create!(stockable: @salsa, kind: :prepped, quantity: 5, unit: "serving")
    beef_lot = StockItem.create!(stockable: @beef, kind: :raw, quantity: 1, unit: "lb")
    session = CookingSession.plate!(@entry)
    session.tasks.each(&:complete!)

    session.reload.finish!

    assert @entry.reload.served?
    assert_equal 3.5, salsa_lot.reload.quantity, "1.5 servings of prepped salsa"
    assert_equal 0.625, beef_lot.reload.quantity, "the beef was cooked today, from raw"
    assert_match "corn tortilla: none in stock", session.stock_notes
  end

  test "a session is finished only when every step is done" do
    session = CookingSession.plate!(@entry)

    assert_raises(ArgumentError) { session.finish! }
  end

  test "stock that runs short is noted" do
    StockItem.create!(stockable: @beef, kind: :raw, quantity: 0.1, unit: "lb")
    session = CookingSession.prep!([ { component: @beef_filling, servings: 2 } ])
    session.sequence_in_recipe_order!
    session.tasks.each(&:complete!)

    session.reload.finish!

    assert_match "ground beef: 0.4 lb short", session.stock_notes
  end

  test "cook once, freeze half: a prep batch can set servings aside for the freezer" do
    @salsa.update!(freezer_life_days: 90)
    session = CookingSession.prep!([ { component: @salsa, servings: 4, frozen_servings: 2 } ])
    session.sequence_in_recipe_order!
    session.tasks.each(&:complete!)

    session.reload.finish!

    batch = session.prep_batches.sole
    assert_equal [ 2, "prepped", Date.current + 5 ], [ batch.stock_item.quantity, batch.stock_item.kind, batch.stock_item.expires_on ]
    assert_equal [ 2, "freezer", Date.current + 90 ], [ batch.frozen_stock_item.quantity, batch.frozen_stock_item.kind, batch.frozen_stock_item.expires_on ]
  end

  test "a batch frozen whole makes no fridge lot" do
    session = CookingSession.prep!([ { component: @salsa, servings: 3, frozen_servings: 3 } ])
    session.sequence_in_recipe_order!
    session.tasks.each(&:complete!)
    session.reload.finish!

    assert_nil session.prep_batches.sole.stock_item
    assert_equal 3, StockItem.freezer.find_by!(stockable: @salsa).quantity
  end

  test "a batch cannot freeze what does not freeze well, or more than it makes" do
    @salsa.update!(freezer_life_days: 0)
    assert_raises(ActiveRecord::RecordInvalid) { CookingSession.prep!([ { component: @salsa, servings: 3, frozen_servings: 1 } ]) }

    assert_raises(ActiveRecord::RecordInvalid) { CookingSession.prep!([ { component: @beef_filling, servings: 3, frozen_servings: 4 } ]) }
    assert_equal 0, CookingSession.count
  end

  test "frozen components count as prepped" do
    StockItem.create!(stockable: @salsa, kind: :freezer, quantity: 5, unit: "serving")

    assert_not Cooking::PrepPlan.new.suggestions.to_h.key?(@salsa)
    assert_equal [ "Brown the beef.", "Let it rest.", "Fill the tortillas." ], CookingSession.plate!(@entry).tasks.map(&:instructions)
  end

  test "a meal whose dish is frozen whole is only reheated, and draws the dish" do
    tacos = StockItem.create!(stockable: @tacos, kind: :freezer, quantity: 4, unit: "serving")
    salsa = StockItem.create!(stockable: @salsa, kind: :prepped, quantity: 4, unit: "serving")

    assert_empty Cooking::PrepPlan.new.suggestions, "nothing to prep for a meal already in the freezer"

    session = CookingSession.plate!(@entry)
    assert_empty session.tasks
    session.finish!

    assert @entry.reload.served?
    assert_equal 2.5, tacos.reload.quantity
    assert_equal 4, salsa.reload.quantity, "what is inside the frozen dish is not drawn again"
  end
end
