# Every afternoon, on the Mac: what to take out of the freezer tonight, as
# reminders due this evening. Anything already on the list and not ticked is
# skipped, so running it again adds only what is new. Where Reminders is not
# there (a container, anything but macOS) it does nothing, and says so in the
# log.
class ThawReminderJob < ApplicationJob
  def perform
    thaws = ThawPlan.new.due
    return if thaws.empty?

    unless Reminders.available?
      Rails.logger.info("#{thaws.size} thaw reminders not sent: Reminders is not available here")
      return
    end

    Reminders.add(thaws.map(&:to_reminder), list: Reminders.thaw_list_name)
  rescue Reminders::Error => e
    Rails.logger.error("Thaw reminders not sent: #{e.message}")
  end
end
