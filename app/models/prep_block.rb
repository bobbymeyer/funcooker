# A prep session booked for a time: the batches to make, and when. It goes
# on the Mac's Calendar as an event, kept in step as it is moved, changed or
# deleted. Starting it makes the cooking session.
#
# batches: [{ "component_id", "servings", "frozen_servings" }]
class PrepBlock < ApplicationRecord
  belongs_to :cooking_session, optional: true

  validates :starts_at, :ends_at, presence: true
  validates :ends_at, comparison: { greater_than: :starts_at }, if: -> { starts_at && ends_at }
  validate :batches_make_sense

  scope :overlapping, ->(from, to) { where(starts_at: ...to).where("ends_at > ?", from) }
  scope :upcoming, -> { where(cooking_session_id: nil).where("ends_at > ?", Time.current).order(:starts_at) }

  after_commit :sync_calendar_later

  Batch = Struct.new(:component, :servings, :frozen_servings, keyword_init: true)

  # Books the batches from the given start, for as long as they take.
  def self.book(batches, starts_at:)
    new(starts_at:, batches: batches.map { |batch| { "component_id" => batch[:component].id, "servings" => batch[:servings].to_s, "frozen_servings" => batch[:frozen_servings].to_s } }).tap do |block|
      block.ends_at = starts_at + block.estimate.minutes.minutes if starts_at
      block.save
    end
  end

  def batch_list
    components = Component.includes(:steps).where(id: batches.map { |batch| batch["component_id"] }).index_by(&:id)
    batches.filter_map do |batch|
      component = components[batch["component_id"].to_i]
      Batch.new(component:, servings: batch["servings"].to_d, frozen_servings: batch["frozen_servings"].to_d) if component
    end
  end

  def estimate
    Cooking::PrepEstimate.new(batch_list.map(&:component))
  end

  def title
    "Prep: #{batch_list.map { |batch| batch.component.name }.to_sentence}"
  end

  def notes
    lines = batch_list.map do |batch|
      "#{batch.component.name} ×#{format(batch.servings)}#{" (#{format(batch.frozen_servings)} to freeze)" if batch.frozen_servings.positive?}"
    end
    lines << "About #{estimate.minutes} min, #{estimate.active_minutes} hands-on."
    lines.join("\n")
  end

  # The event on the calendar: keyed by id, so it is moved rather than added
  # again.
  def to_event(base_url)
    { key: id.to_s, title:, start: starts_at.iso8601, end: ends_at.iso8601, notes:, url: "#{base_url}/cook/blocks/#{id}/edit" }
  end

  def start!
    transaction do
      session = CookingSession.prep!(batch_list.map { |batch| { component: batch.component, servings: batch.servings, frozen_servings: batch.frozen_servings } })
      update!(cooking_session: session)
      session
    end
  end

  private
    def format(amount)
      amount.round(3).to_s("F").sub(/\.0\z/, "")
    end

    def batches_make_sense
      list = batch_list
      errors.add(:batches, "need at least one component") if list.empty?
      list.each do |batch|
        name = batch.component.name
        errors.add(:batches, "#{name} needs servings above 0") unless batch.servings.positive?
        errors.add(:batches, "#{name} cannot freeze more than it makes") if batch.frozen_servings.negative? || batch.frozen_servings > batch.servings
        errors.add(:batches, "#{name} does not freeze well") if batch.frozen_servings.positive? && !batch.component.freezable?
      end
    end

    def sync_calendar_later
      CalendarSyncJob.perform_later if MacCalendar.available?
    end
end
