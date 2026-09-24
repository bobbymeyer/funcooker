class HouseholdsController < ApplicationController
  def update
    household = Household.current

    if household.update(params.expect(household: %i[ time_zone thaw_reminder_hour prep_day_starts prep_day_ends busy_calendars prep_calendar ]))
      redirect_to household_members_path, notice: "Saved. It is #{l(Time.current.in_time_zone(household.time_zone), format: :short)} there."
    else
      redirect_to household_members_path, alert: household.errors.full_messages.to_sentence
    end
  end
end
