require "test_helper"

class CalendarReadJobTest < ActiveJob::TestCase
  setup { @defaults = [ MacScript.mac, MacScript.osascript, MacScript.runner ] }
  teardown { MacScript.mac, MacScript.osascript, MacScript.runner = @defaults }

  test "on the Mac, reads busy times and syncs prep blocks" do
    actions = []
    MacScript.mac = -> { true }
    MacScript.osascript = -> { "/usr/bin/osascript" }
    MacScript.runner = ->(*command) do
      actions << JSON.parse(command.last)["action"]
      [ '{"busy":[],"added":0,"updated":0,"removed":0}', "", Struct.new(:success?, :exitstatus).new(true, 0) ]
    end

    CalendarReadJob.perform_now

    assert_equal %w[ busy sync ], actions
  end

  test "does nothing off the Mac" do
    MacScript.mac = -> { false }
    MacScript.runner = ->(*) { flunk "should not run" }

    assert_nothing_raised { CalendarReadJob.perform_now }
  end
end
