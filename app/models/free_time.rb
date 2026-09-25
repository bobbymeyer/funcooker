# Where a prep session fits: within the household's prep hours each day,
# around what the calendar says is busy and the prep blocks already booked.
# All-day events do not count: they are birthdays and trips more often than
# busy days. Returns the first stretch each day long enough.
class FreeTime
  Slot = Struct.new(:starts_at, :free_until, keyword_init: true) do
    def minutes
      ((free_until - starts_at) / 60).floor
    end
  end

  def initialize(from:, to:, minutes:, household: Household.current)
    @from, @to, @minutes, @household = from, to, minutes, household
  end

  def slots
    taken = BusyTime.overlapping(@from, @to).where(all_day: false).pluck(:starts_at, :ends_at) +
      PrepBlock.overlapping(@from, @to).pluck(:starts_at, :ends_at)
    taken.sort_by!(&:first)

    (@from.to_date..@to.to_date).filter_map do |day|
      opens = [ day.in_time_zone.change(hour: @household.prep_day_starts), @from ].max
      closes = [ day.in_time_zone + @household.prep_day_ends.hours, @to ].min
      first_gap(opens, closes, taken)
    end
  end

  private
    def first_gap(opens, closes, taken)
      cursor = opens
      taken.each do |starts_at, ends_at|
        next if ends_at <= cursor
        break if starts_at >= closes

        return Slot.new(starts_at: cursor, free_until: starts_at) if fits?(cursor, starts_at)

        cursor = [ cursor, ends_at ].max
      end
      Slot.new(starts_at: cursor, free_until: closes) if fits?(cursor, closes)
    end

    def fits?(starts_at, ends_at)
      ends_at - starts_at >= @minutes.minutes
    end
end
