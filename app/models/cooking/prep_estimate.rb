# How long a prep session of these components takes, from their steps. Hands
# are needed for every active step, one at a time; a passive step (resting,
# the oven) runs alongside other work. So the session takes the longer of all
# its active time together and the longest single component made start to
# finish. A step with no time counts as UNTIMED_MINUTES of active work.
class Cooking::PrepEstimate
  UNTIMED_MINUTES = 5

  def initialize(components)
    @components = components.uniq
  end

  def active_minutes
    steps.select(&:active?).sum { |step| step_minutes(step) }
  end

  def minutes
    [ active_minutes, @components.map { |component| component.steps.sum { |step| step_minutes(step) } }.max || 0 ].max
  end

  def untimed_steps
    steps.count { |step| step.duration_minutes.nil? }
  end

  private
    def steps
      @steps ||= @components.flat_map(&:steps)
    end

    def step_minutes(step)
      step.duration_minutes || UNTIMED_MINUTES
    end
end
