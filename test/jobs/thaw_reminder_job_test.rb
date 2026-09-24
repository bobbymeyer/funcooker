require "test_helper"

class ThawReminderJobTest < ActiveJob::TestCase
  setup do
    HouseholdMember.create!(name: "Bobby")
    stew = Component.create!(name: "beef stew")
    ScheduleEntry.create!(served_on: Date.current + 1, dish: stew)
    StockItem.create!(stockable: stew, kind: :freezer, quantity: 2, unit: "serving")
    @defaults = [ MacScript.mac, MacScript.osascript, MacScript.runner ]
  end

  teardown do
    MacScript.mac, MacScript.osascript, MacScript.runner = @defaults
  end

  test "sends tonight's thaws to the thaw list, due this evening" do
    sent = nil
    MacScript.mac = -> { true }
    MacScript.osascript = -> { "/usr/bin/osascript" }
    MacScript.runner = ->(*command) { sent = JSON.parse(command.last); [ '{"list":"Reminders","added":1,"skipped":0}', "", Struct.new(:success?, :exitstatus).new(true, 0) ] }

    ThawReminderJob.perform_now(force: true)

    assert_equal "Reminders", sent["list"]
    assert_equal [ "Thaw beef stew, 1 serving, for #{(Date.current + 1).strftime("%A")}" ], sent["items"].map { |item| item["title"] }
    assert Time.iso8601(sent["items"].first["due"]) >= Time.current - 5
  end

  test "does nothing where there is no Reminders" do
    MacScript.mac = -> { false }
    MacScript.runner = ->(*) { flunk "should not run" }

    assert_nothing_raised { ThawReminderJob.perform_now(force: true) }
  end

  test "runs hourly, and sends only at the household's hour, in its time zone" do
    sent = 0
    MacScript.mac = -> { true }
    MacScript.osascript = -> { "/usr/bin/osascript" }
    MacScript.runner = ->(*) { sent += 1; [ '{"list":"Reminders","added":1,"skipped":0}', "", Struct.new(:success?, :exitstatus).new(true, 0) ] }
    Household.current.update!(time_zone: "America/Los_Angeles", thaw_reminder_hour: 16)

    la = Time.find_zone("America/Los_Angeles")
    today = Date.current

    travel_to(la.local(today.year, today.month, today.day, 15, 5)) { ThawReminderJob.perform_now }
    assert_equal 0, sent

    travel_to(la.local(today.year, today.month, today.day, 16, 5)) { ThawReminderJob.perform_now }
    assert_equal 1, sent
  end
end
