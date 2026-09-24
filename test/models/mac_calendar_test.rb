require "test_helper"

class MacCalendarTest < ActiveSupport::TestCase
  Status = Struct.new(:success?, :exitstatus)

  setup do
    @defaults = [ MacScript.mac, MacScript.osascript, MacScript.runner ]
    @calls = []
    MacScript.mac = -> { true }
    MacScript.osascript = -> { "/usr/bin/osascript" }
  end

  teardown do
    MacScript.mac, MacScript.osascript, MacScript.runner = @defaults
  end

  def replying(json)
    MacScript.runner = ->(*command) { @calls << JSON.parse(command.last); [ json.to_json, "", Status.new(true, 0) ] }
  end

  test "reading stores the busy times for the window, replacing what was there" do
    Household.current.update!(busy_calendars: "Family, Work")
    old = BusyTime.create!(starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
    start = Time.current.beginning_of_day + 1.day + 10.hours
    replying(busy: [ { start: start.utc.iso8601, end: (start + 1.hour).utc.iso8601, all_day: false }, { start: "nonsense", end: "" } ])

    assert_equal 1, MacCalendar.read!

    assert_equal({ "action" => "busy", "calendars" => [ "Family", "Work" ] }, @calls.sole.slice("action", "calendars"))
    assert_not BusyTime.exists?(old.id)
    assert_equal [ start ], BusyTime.pluck(:starts_at)
    assert Household.current.calendar_read_at
  end

  test "syncing sends every booked block in the window, keyed, to the prep calendar" do
    Household.current.update!(prep_calendar: "Kitchen")
    rice = Component.create!(name: "rice")
    block = PrepBlock.create!(starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour, batches: [ { "component_id" => rice.id, "servings" => "4" } ])
    replying(added: 1, updated: 0, removed: 0)

    MacCalendar.sync!("http://mac.local:3000")

    payload = @calls.sole
    assert_equal [ "sync", "Kitchen", MacCalendar::MARKER ], payload.values_at("action", "calendar", "marker")
    assert_equal [ [ block.id.to_s, "Prep: rice" ] ], payload["events"].map { |event| event.values_at("key", "title") }
  end

  test "a refusal says where to grant access" do
    MacScript.runner = ->(*) { [ "", "Error: Calendar access not granted", Status.new(false, 1) ] }

    error = assert_raises(MacScript::Error) { MacCalendar.read! }
    assert_match "Privacy & Security → Calendars", error.message
  end
end
