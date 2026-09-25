# A stretch the household's calendar says is taken, as last read from the
# Mac's Calendar. Replaced wholesale on each read for the window read.
class BusyTime < ApplicationRecord
  validates :starts_at, :ends_at, presence: true

  scope :overlapping, ->(from, to) { where(starts_at: ...to).where("ends_at > ?", from) }

  # times: [{ "start", "end", "all_day" }] as the script prints them.
  def self.replace!(times, from:, to:)
    transaction do
      overlapping(from, to).delete_all
      rows = times.filter_map do |time|
        starts_at, ends_at = Time.iso8601(time["start"].to_s), Time.iso8601(time["end"].to_s)
        { starts_at:, ends_at:, all_day: time["all_day"] == true } if ends_at > starts_at
      rescue ArgumentError
        nil
      end
      insert_all!(rows) if rows.any?
      Household.current.update!(calendar_read_at: Time.current)
      rows.size
    end
  end
end
