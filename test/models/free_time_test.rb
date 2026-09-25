require "test_helper"

class FreeTimeTest < ActiveSupport::TestCase
  setup do
    Household.current.update!(prep_day_starts: 9, prep_day_ends: 21)
    @day = Time.zone.local(2026, 9, 26)
  end

  def slots(minutes, from: @day, to: @day + 2.days)
    FreeTime.new(from:, to:, minutes:).slots.map { |slot| [ slot.starts_at.strftime("%a %H:%M"), slot.free_until.strftime("%H:%M") ] }
  end

  test "the first stretch each day long enough, within prep hours" do
    BusyTime.create!(starts_at: @day.change(hour: 8), ends_at: @day.change(hour: 10))
    BusyTime.create!(starts_at: @day.change(hour: 11), ends_at: @day.change(hour: 15))

    assert_equal [ [ "Sat 15:00", "21:00" ], [ "Sun 09:00", "21:00" ] ], slots(90)
    assert_equal [ [ "Sat 10:00", "11:00" ], [ "Sun 09:00", "21:00" ] ], slots(60)
  end

  test "booked prep counts as busy, and all-day events do not" do
    BusyTime.create!(starts_at: @day, ends_at: @day + 1.day, all_day: true)
    PrepBlock.create!(starts_at: @day.change(hour: 9), ends_at: @day.change(hour: 20), batches: [ { "component_id" => Component.create!(name: "rice").id, "servings" => "2" } ])

    assert_equal [ [ "Sun 09:00", "21:00" ] ], slots(90)
  end

  test "starts no earlier than from" do
    assert_equal [ [ "Sat 17:30", "21:00" ] ], slots(60, from: @day.change(hour: 17, min: 30), to: @day.change(hour: 23))
  end
end
