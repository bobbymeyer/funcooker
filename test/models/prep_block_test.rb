require "test_helper"

class PrepBlockTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @beef = Component.create!(name: "seasoned beef", freezer_life_days: 60)
    @beef.steps.create!(position: 1, instructions: "Brown.", mode: :active, duration_minutes: 20)
    @beef.steps.create!(position: 2, instructions: "Simmer.", mode: :passive, duration_minutes: 60)
    @salsa = Component.create!(name: "salsa verde")
    @salsa.steps.create!(position: 1, instructions: "Roast.", mode: :active, duration_minutes: 15)
    @salsa.steps.create!(position: 2, instructions: "Blend.", mode: :active)
    @defaults = [ MacScript.mac, MacScript.osascript, MacScript.runner ]
  end

  teardown do
    MacScript.mac, MacScript.osascript, MacScript.runner = @defaults
  end

  test "an estimate is all the hands-on time, or the longest component start to finish" do
    estimate = Cooking::PrepEstimate.new([ @beef, @salsa ])

    assert_equal 40, estimate.active_minutes, "20 + 15 + 5 for the untimed blend"
    assert_equal 80, estimate.minutes, "the beef's 20 and 60 run end to end; the salsa fits in its simmer"
    assert_equal 1, estimate.untimed_steps
  end

  test "booking takes as long as the estimate, and becomes a calendar event" do
    starts_at = Time.zone.local(2026, 9, 26, 10)
    block = PrepBlock.book([ { component: @beef, servings: 4, frozen_servings: 2 }, { component: @salsa, servings: 3, frozen_servings: 0 } ], starts_at:)

    assert block.persisted?
    assert_equal starts_at + 80.minutes, block.ends_at
    assert_equal "Prep: seasoned beef and salsa verde", block.title
    assert_equal "seasoned beef ×4 (2 to freeze)\nsalsa verde ×3\nAbout 80 min, 40 hands-on.", block.notes
    event = block.to_event("http://mac.local:3000")
    assert_equal [ block.id.to_s, "http://mac.local:3000/cook/blocks/#{block.id}/edit", starts_at.iso8601 ], event.values_at(:key, :url, :start)
  end

  test "a block needs components, servings, and nothing frozen that does not freeze" do
    @salsa.update!(freezer_life_days: 0)
    starts_at = Time.zone.local(2026, 9, 26, 10)

    assert_not PrepBlock.book([], starts_at:).persisted?
    block = PrepBlock.book([ { component: @salsa, servings: 3, frozen_servings: 1 } ], starts_at:)
    assert_includes block.errors.full_messages, "Batches salsa verde does not freeze well"
    assert_not PrepBlock.new(starts_at:, ends_at: starts_at - 1.hour, batches: [ { "component_id" => @beef.id, "servings" => "1" } ]).valid?
  end

  test "starting a block makes its session" do
    block = PrepBlock.book([ { component: @beef, servings: 4, frozen_servings: 2 } ], starts_at: 1.hour.from_now)

    session = block.start!

    assert_equal [ [ @beef, 4, 2 ] ], session.prep_batches.map { |batch| [ batch.component, batch.servings, batch.frozen_servings ] }
    assert_equal session, block.reload.cooking_session
    assert_not_includes PrepBlock.upcoming, block
  end

  test "on the Mac, a change is synced to the calendar" do
    MacScript.mac = -> { true }
    MacScript.osascript = -> { "/usr/bin/osascript" }

    assert_enqueued_with(job: CalendarSyncJob) do
      PrepBlock.book([ { component: @beef, servings: 1, frozen_servings: 0 } ], starts_at: 1.hour.from_now)
    end
  end

  test "off the Mac, nothing is enqueued" do
    MacScript.mac = -> { false }

    assert_no_enqueued_jobs(only: CalendarSyncJob) do
      PrepBlock.book([ { component: @beef, servings: 1, frozen_servings: 0 } ], starts_at: 1.hour.from_now)
    end
  end
end
