# Settings for the whole household: one row. Its time zone is what today and
# this evening mean everywhere in the app; the thaw reminder hour is when, in
# that zone, the day's thaws go to Reminders. The prep hours bound when a
# prep block may be booked, the busy calendars are the ones that count
# against it (all of them when blank), and the prep calendar is where booked
# blocks go (the Mac's default when blank).
class Household < ApplicationRecord
  validate :known_time_zone
  validates :thaw_reminder_hour, numericality: { only_integer: true, in: 0..23 }
  validates :prep_day_starts, numericality: { only_integer: true, in: 0..23 }
  validates :prep_day_ends, numericality: { only_integer: true, in: 1..24, greater_than: :prep_day_starts }

  def self.current
    first || create!
  end

  # [label, tz database name] for a select: "(GMT-08:00) Pacific Time (US &
  # Canada)", "America/Los_Angeles".
  def self.time_zone_options
    ActiveSupport::TimeZone.all.uniq { |zone| zone.tzinfo.name }.map { |zone| [ zone.to_s, zone.tzinfo.name ] }
  end

  # The calendar names in busy_calendars; empty means every calendar.
  def busy_calendar_names
    busy_calendars.to_s.split(",").map(&:squish).compact_blank
  end

  # Runs the block in the household's time zone.
  def self.in_zone(&block)
    Time.use_zone(current.time_zone, &block)
  end

  private
    def known_time_zone
      errors.add(:time_zone, "is not a time zone") unless ActiveSupport::TimeZone[time_zone.to_s]
    end
end
