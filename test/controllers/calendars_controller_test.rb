require "test_helper"

class CalendarsControllerTest < ActionDispatch::IntegrationTest
  test "the Mac's script gets what to sync and what to read, and posts back what is busy" do
    rice = Component.create!(name: "rice")
    PrepBlock.create!(starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour, batches: [ { "component_id" => rice.id, "servings" => "4" } ])

    get calendar_path(format: :json)
    body = response.parsed_body
    assert_equal "sync", body.dig("sync", "action")
    assert_match %r{\Ahttp://www.example.com/cook/blocks/\d+/edit\z}, body.dig("sync", "events", 0, "url")
    assert_equal "busy", body.dig("busy", "action")

    start = Time.current.beginning_of_day + 1.day + 10.hours
    post busy_calendar_path, params: { busy: [ { start: start.iso8601, end: (start + 1.hour).iso8601, all_day: false } ] }, as: :json
    assert_equal({ "stored" => 1 }, response.parsed_body)
    assert_equal 1, BusyTime.count
  end

  test "reading from here, off the Mac, says why not" do
    defaults = MacScript.mac
    MacScript.mac = -> { false }

    post read_calendar_path

    assert_match "not running on macOS", flash[:alert]
  ensure
    MacScript.mac = defaults
  end
end
