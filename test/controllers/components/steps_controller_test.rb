require "test_helper"

class Components::StepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @component = Component.create!(name: "Chili")
    @step = @component.steps.create!(position: 1, instructions: "Brown the beef.")
  end

  test "a new step goes after the last" do
    get new_component_step_path(@component)
    assert_select "input[name='step[position]'][value='2']"

    post component_steps_path(@component), params: { step: { position: "2", instructions: "Simmer.", phase: "prep", mode: "passive", duration_minutes: "30" } }

    assert_redirected_to @component
    step = @component.steps.last
    assert_equal [ 2, "passive", 30 ], [ step.position, step.mode, step.duration_minutes ]
  end

  test "update" do
    get edit_step_path(@step)
    assert_response :success

    patch step_path(@step), params: { step: { phase: "plate" } }
    assert_redirected_to @component
    assert @step.reload.plate?
  end

  test "destroy" do
    delete step_path(@step)
    assert_redirected_to @component
    assert_empty @component.steps.reload
  end
end
