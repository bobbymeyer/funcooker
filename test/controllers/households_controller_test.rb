require "test_helper"

class HouseholdsControllerTest < ActionDispatch::IntegrationTest
  test "the household's time zone and thaw reminder hour are set on the household page" do
    get household_members_path
    assert_select "select[name='household[time_zone]'] option[value='America/Los_Angeles']", /Pacific Time/

    patch household_path, params: { household: { time_zone: "America/Los_Angeles", thaw_reminder_hour: "17" } }

    assert_redirected_to household_members_path
    assert_equal [ "America/Los_Angeles", 17 ], [ Household.current.time_zone, Household.current.thaw_reminder_hour ]
  end

  test "requests run in the household's time zone" do
    Household.current.update!(time_zone: "Pacific/Kiritimati") # UTC+14: 11am UTC on the 24th is 1am on the 25th
    travel_to Time.utc(2026, 9, 24, 11) do
      chili = Component.create!(name: "chili")
      ScheduleEntry.create!(served_on: Date.new(2026, 9, 24), dish: chili)
      ScheduleEntry.create!(served_on: Date.new(2026, 9, 25), dish: chili)

      get schedule_entries_path

      assert_select ".up-next .hint", /September 25, 2026/
    end
  end

  test "an unknown time zone is refused" do
    patch household_path, params: { household: { time_zone: "Mars/Olympus_Mons" } }

    assert_equal "Time zone is not a time zone", flash[:alert]
    assert_equal "UTC", Household.current.time_zone
  end

  test "a new household starts in Los Angeles" do
    Household.delete_all

    assert_equal "America/Los_Angeles", Household.current.time_zone
  end
end
