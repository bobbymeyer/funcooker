require "test_helper"

class CookingSessionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    HouseholdMember.create!(name: "Bobby")
    @salsa = Component.create!(name: "salsa verde")
    @salsa.steps.create!(position: 1, instructions: "Blend the tomatillos.")
    @salsa.steps.create!(position: 2, instructions: "Chill.", mode: :passive, duration_minutes: 30)
    @tacos = Component.create!(name: "tacos")
    ComponentPart.create!(parent: @tacos, child: @salsa, quantity: 1, unit: "serving")
    @tacos.steps.create!(position: 1, instructions: "Fill the tortillas.", phase: :plate)
    @entry = ScheduleEntry.create!(served_on: Date.current, dish: @tacos)
  end

  test "the prep planner suggests what the meals ahead need" do
    get new_cooking_session_path

    assert_select "a", "salsa verde"
    assert_select "input[name='batches[0][servings]'][value='1']"
  end

  test "starting a prep session with the picked components" do
    assert_enqueued_jobs 1, only: CookingSequenceJob do
      post cooking_sessions_path, params: { batches: {
        "0" => { component_id: @salsa.id, include: "1", servings: "4" },
        "1" => { component_id: "", include: "0", servings: "4" }
      } }
    end

    session = CookingSession.last
    assert_redirected_to session
    assert_equal [ [ @salsa, 4 ] ], session.prep_batches.map { |batch| [ batch.component, batch.servings ] }

    follow_redirect!
    assert_select "p", /Ordering the steps/
  end

  test "starting a prep session with servings for the freezer" do
    get new_cooking_session_path
    assert_select "input[name='batches[0][frozen_servings]']"

    post cooking_sessions_path, params: { batches: { "0" => { component_id: @salsa.id, include: "1", servings: "6", frozen_servings: "3" } } }
    assert_equal [ [ 6, 3 ] ], CookingSession.last.prep_batches.map { |batch| [ batch.servings, batch.frozen_servings ] }

    @salsa.update!(freezer_life_days: 0)
    post cooking_sessions_path, params: { batches: { "0" => { component_id: @salsa.id, include: "1", servings: "6", frozen_servings: "3" } } }
    assert_redirected_to new_cooking_session_path
    assert_match "does not freeze well", flash[:alert]
  end

  test "starting with nothing picked" do
    post cooking_sessions_path, params: { batches: { "0" => { component_id: @salsa.id, include: "0", servings: "4" } } }
    assert_redirected_to new_cooking_session_path
  end

  test "cooking a meal walks its steps and finishes by serving it" do
    post cook_schedule_entry_path(@entry)
    session = CookingSession.last
    assert_redirected_to session

    follow_redirect!
    assert_select ".step__instructions", "Blend the tomatillos."
    blend, chill, fill = session.tasks

    post complete_cooking_task_path(blend)
    follow_redirect!
    assert_select "button", "Start 30 min"

    post start_cooking_task_path(chill)
    follow_redirect!
    assert_select ".timers [data-controller=timer]"
    assert_select ".step__instructions", "Fill the tortillas."

    post complete_cooking_task_path(fill)
    post complete_cooking_task_path(chill)
    follow_redirect!
    assert_select "button", "Finish and mark served"

    post finish_cooking_session_path(session)
    assert @entry.reload.served?
    assert session.reload.done?
  end

  test "cooking the same meal again resumes its session" do
    post cook_schedule_entry_path(@entry)
    post cook_schedule_entry_path(@entry)

    assert_equal 1, CookingSession.count
  end

  test "undo a step" do
    session = CookingSession.plate!(@entry)
    task = session.tasks.first
    task.complete!

    post reopen_cooking_task_path(task)
    assert_nil task.reload.completed_at
  end

  test "a failed ordering offers recipe order" do
    session = CookingSession.prep!([ { component: @salsa, servings: 1 } ])
    session.update!(status: :failed, error: "The model is down")

    get cooking_session_path(session)
    assert_select "p.errors", "The model is down"

    post recipe_order_cooking_session_path(session)
    assert session.reload.ready?
  end

  test "index and destroy" do
    session = CookingSession.plate!(@entry)

    get cooking_sessions_path
    assert_select "td", "plate: tacos"

    delete cooking_session_path(session)
    assert_not CookingSession.exists?(session.id)
  end
end
