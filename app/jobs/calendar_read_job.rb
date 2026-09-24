# Hourly, on the Mac: reads the calendar's busy times and puts the booked
# prep blocks on it. Where the calendar is not there (a container) it does
# nothing: the Mac runs lib/calendar/calendar.js against the app instead.
class CalendarReadJob < ApplicationJob
  def perform
    return unless MacCalendar.available?

    MacCalendar.read!
    MacCalendar.sync!
  rescue MacScript::Error => e
    Rails.logger.error("Calendar not read: #{e.message}")
  end
end
