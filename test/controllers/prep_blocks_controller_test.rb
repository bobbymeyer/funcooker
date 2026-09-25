require "test_helper"

class PrepBlocksControllerTest < ActionDispatch::IntegrationTest
  setup do
    Household.current.update!(prep_day_starts: 0, prep_day_ends: 24)
    HouseholdMember.create!(name: "Bobby")
    @salsa = Component.create!(name: "salsa verde")
    @salsa.steps.create!(position: 1, instructions: "Blend.", mode: :active, duration_minutes: 30)
    @tacos = Component.create!(name: "tacos")
    ComponentPart.create!(parent: @tacos, child: @salsa, quantity: 1, unit: "serving")
    ScheduleEntry.create!(served_on: Date.current + 2, dish: @tacos)
  end

  test "the planner shows how long prep takes and where it fits, and books a time" do
    get new_cooking_session_path
    assert_select "strong", "30 min"
    assert_select "p", /first meal that needs it is tacos/
    button = css_select("button[formaction='#{prep_blocks_path}']").first
    assert button

    post prep_blocks_path, params: { starts_at: button["value"], batches: { "0" => { component_id: @salsa.id, include: "1", servings: "2", frozen_servings: "0" } } }

    block = PrepBlock.sole
    assert_redirected_to cooking_sessions_path
    assert_equal 30.minutes, block.ends_at - block.starts_at
    follow_redirect!
    assert_select "td", /salsa verde ×2/
  end

  test "edit, move, and delete a block" do
    block = PrepBlock.create!(starts_at: 1.day.from_now.change(hour: 10), ends_at: 1.day.from_now.change(hour: 11), batches: [ { "component_id" => @salsa.id, "servings" => "2", "frozen_servings" => "0" } ])

    get edit_prep_block_path(block)
    assert_select "input[name='prep_block[batches][0][servings]'][value='2']"

    later = 2.days.from_now.change(hour: 15)
    patch prep_block_path(block), params: { prep_block: { starts_at: later.strftime("%Y-%m-%dT%H:%M"), ends_at: (later + 1.hour).strftime("%Y-%m-%dT%H:%M"), batches: { "0" => { component_id: @salsa.id, servings: "5", frozen_servings: "0" } } } }
    assert_redirected_to cooking_sessions_path
    assert_equal [ later, "5" ], [ block.reload.starts_at, block.batches.sole["servings"] ]

    patch prep_block_path(block), params: { prep_block: { batches: { "0" => { component_id: @salsa.id, servings: "0" } } } }
    assert_response :unprocessable_entity

    delete prep_block_path(block)
    assert_not PrepBlock.exists?(block.id)
  end

  test "start a block" do
    block = PrepBlock.create!(starts_at: 1.hour.from_now, ends_at: 2.hours.from_now, batches: [ { "component_id" => @salsa.id, "servings" => "2", "frozen_servings" => "0" } ])

    post start_prep_block_path(block)

    assert_redirected_to block.reload.cooking_session
  end
end
