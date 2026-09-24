# Puts booked prep blocks on the Mac's Calendar after one is booked, moved or
# deleted. A calendar that cannot be reached leaves it for the next sync, and
# says so in the log.
class CalendarSyncJob < ApplicationJob
  def perform
    MacCalendar.sync!
  rescue MacScript::Error => e
    Rails.logger.error("Prep blocks not synced to Calendar: #{e.message}")
  end
end
