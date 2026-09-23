# Asks the model to order a prep session's steps. It gets every step with its
# component, whether it is active or passive and how long it takes, and
# returns them in clusters. Whatever it returns is repaired: unknown or
# repeated steps are dropped, missing ones appended, and each component's
# steps are put back in their recipe order within the positions they got.
class CookingSession::Sequencer
  def initialize(session)
    @session = session
    @tasks = session.tasks.includes(step: :component).to_a
  end

  def call
    reply = Llm.extract(schema:, input:, instructions: <<~TEXT)
      You order a batch-cooking session in a home kitchen, where one person preps several components at once.
      - Put long passive steps (marinating, soaking, baking, simmering unattended, resting) as early as they can go, so their waiting absorbs active work.
      - Start the long, multi-step components first; let quick tasks fill the dead time.
      - Only one active step happens at a time.
      - Group the steps into clusters by technique or station (knife work, stovetop, oven, blender, assembly), and label each cluster plainly.
      - A component's steps must stay in their order.
      Use every step id exactly once.
    TEXT

    apply(Array(reply["clusters"]))
  end

  private
    def input
      @tasks.map do |task|
        step = task.step
        timing = [ step.mode, ("#{step.duration_minutes} min" if step.duration_minutes) ].compact.join(", ")
        "#{task_id(task)}: [#{task.component.name}, #{timing}] #{step.instructions}"
      end.join("\n")
    end

    def schema
      {
        type: "object",
        properties: {
          clusters: {
            type: "array",
            items: {
              type: "object",
              properties: {
                label: { type: "string" },
                steps: { type: "array", items: { type: "string", enum: @tasks.map { |task| task_id(task) } } }
              },
              required: %w[ label steps ],
              additionalProperties: false
            }
          }
        },
        required: %w[ clusters ],
        additionalProperties: false
      }
    end

    def apply(clusters)
      by_id = @tasks.index_by { |task| task_id(task) }
      ordered = []
      labels = {}
      clusters.each do |cluster|
        Array(cluster["steps"]).each do |id|
          task = by_id[id] or next
          next if ordered.include?(task)

          ordered << task
          labels[task] = cluster["label"].to_s.squish.presence
        end
      end
      ordered += @tasks - ordered

      # Each component keeps the positions it was given, filled in recipe order.
      ordered.group_by(&:component).each_value do |component_tasks|
        slots = component_tasks.map { |task| ordered.index(task) }.sort
        component_tasks.sort_by { |task| task.step.position }.zip(slots).each { |task, slot| ordered[slot] = task }
      end

      CookingTask.transaction do
        ordered.each.with_index(1) do |task, position|
          task.update!(position:, cluster: labels[task] || task.component.name)
        end
      end
    end

    def task_id(task) = "t#{task.id}"
end
