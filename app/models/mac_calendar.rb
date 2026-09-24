# The Mac's Calendar, through lib/calendar/calendar.js: busy times read into
# BusyTime, prep blocks written out as events. The app does both itself when
# it runs on the Mac; in a container, the Mac runs the script against the app
# (calendar.json and calendar/busy) and the same payloads go the other way.
module MacCalendar
  SCRIPT = Rails.root.join("lib/calendar/calendar.js")
  PERMISSION_HINT = "The first run asks macOS for access to Calendar: allow it, or turn it on in System Settings → Privacy & Security → Calendars (full access, for the process running the app)."
  MARKER = "funcooker prep block"
  READ_DAYS = 14
  SYNC_DAYS = 60

  extend self

  def available?
    MacScript.available?
  end

  # Reads the calendar's busy times for the days ahead.
  def read!
    request = busy_request
    store_busy!(MacScript.run(SCRIPT, request, permission_hint: PERMISSION_HINT, what: "Calendar")["busy"], request)
  end

  # Makes the calendar's prep block events match the booked blocks.
  def sync!(base_url = Rails.configuration.x.app_url)
    MacScript.run(SCRIPT, sync_payload(base_url), permission_hint: PERMISSION_HINT, what: "Calendar")
  end

  def busy_request
    from = Time.current.beginning_of_day
    { action: "busy", from: from.iso8601, to: (from + READ_DAYS.days).iso8601, calendars: Household.current.busy_calendar_names }
  end

  def sync_payload(base_url)
    from, to = Time.current.beginning_of_day - 1.day, Time.current.beginning_of_day + SYNC_DAYS.days
    {
      action: "sync", calendar: Household.current.prep_calendar.presence, marker: MARKER, from: from.iso8601, to: to.iso8601,
      events: PrepBlock.overlapping(from, to).order(:starts_at).map { |block| block.to_event(base_url) }
    }
  end

  # Stores busy times read for the window the request asked about.
  def store_busy!(busy, request)
    BusyTime.replace!(Array(busy), from: Time.iso8601(request[:from]), to: Time.iso8601(request[:to]))
  end
end
