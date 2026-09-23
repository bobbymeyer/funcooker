require "test_helper"

class ThawReminderJobTest < ActiveJob::TestCase
  setup do
    HouseholdMember.create!(name: "Bobby")
    stew = Component.create!(name: "beef stew")
    ScheduleEntry.create!(served_on: Date.current + 1, dish: stew)
    StockItem.create!(stockable: stew, kind: :freezer, quantity: 2, unit: "serving")
    @defaults = [ Reminders.mac, Reminders.osascript, Reminders.runner ]
  end

  teardown do
    Reminders.mac, Reminders.osascript, Reminders.runner = @defaults
  end

  test "sends tonight's thaws to the thaw list, due this evening" do
    sent = nil
    Reminders.mac = -> { true }
    Reminders.osascript = -> { "/usr/bin/osascript" }
    Reminders.runner = ->(*command) { sent = JSON.parse(command.last); [ '{"list":"Reminders","added":1,"skipped":0}', "", Struct.new(:success?, :exitstatus).new(true, 0) ] }

    ThawReminderJob.perform_now

    assert_equal "Reminders", sent["list"]
    assert_equal [ "Thaw beef stew, 1 serving, for #{(Date.current + 1).strftime("%A")}" ], sent["items"].map { |item| item["title"] }
    assert Time.iso8601(sent["items"].first["due"]) >= Time.current - 5
  end

  test "does nothing where there is no Reminders" do
    Reminders.mac = -> { false }
    Reminders.runner = ->(*) { flunk "should not run" }

    assert_nothing_raised { ThawReminderJob.perform_now }
  end
end
