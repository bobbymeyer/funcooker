# The Mac's Calendar, from the app's side. As JSON, what the Mac's script
# needs to sync prep blocks and read busy times; busy takes back what it
# read. read and sync do both from here, when the app runs on the Mac.
class CalendarsController < ApplicationController
  # The script posts JSON from the Mac, with no session to carry a token.
  skip_forgery_protection only: :busy

  def show
    render json: { sync: MacCalendar.sync_payload(request.base_url), busy: MacCalendar.busy_request }
  end

  def busy
    request_window = MacCalendar.busy_request
    stored = MacCalendar.store_busy!(params.fetch(:busy, []).map { |time| time.permit(:start, :end, :all_day).to_h }, request_window)
    render json: { stored: }
  end

  def read
    count = MacCalendar.read!
    MacCalendar.sync!(request.base_url)
    redirect_back_or_to new_cooking_session_path, notice: "Read #{helpers.pluralize(count, "busy time")} from the calendar, and put the prep blocks on it."
  rescue MacScript::Error => e
    redirect_back_or_to new_cooking_session_path, alert: e.message
  end
end
