# Asks the model how long a component keeps once made, stored the usual way
# for it, and how it knows. Conservative, since the answer sets when prepped
# stock expires.
module Component::ShelfLife
  SCHEMA = {
    type: "object",
    properties: {
      days: { type: "integer" },
      storage: { type: "string" },
      basis: { type: "string" }
    },
    required: %w[ days storage basis ],
    additionalProperties: false
  }.freeze

  extend self

  def estimate(component)
    reply = Llm.extract(schema: SCHEMA, input: describe(component), instructions: <<~TEXT)
      Estimate how many whole days this keeps once it is made, stored the usual way for it: a sealed container in the fridge for most cooked food and sauces, the pantry for a dry spice mix. Follow common food-safety guidance and stay on the conservative side: cooked meat, poultry and fish keep 3 days, cooked grains and most cooked vegetables 4, vinaigrettes and pickles longer.
      - days: the whole number of days.
      - storage: where it is kept, in a few words.
      - basis: the rule you applied, in a few words.
    TEXT

    days = reply["days"].to_i
    raise Llm::Error, "The model gave #{reply["days"].inspect} days" unless days.positive?

    { days:, note: [ reply["storage"], reply["basis"] ].map { |part| part.to_s.squish }.compact_blank.join("; ").truncate(200) }
  end

  private
    def describe(component)
      lines = component.component_ingredients.includes(:ingredient, :ingredient_family).map { |line| line.ingredient&.name || "any #{line.ingredient_family.name}" }
      parts = component.children.map(&:name)
      <<~TEXT
        #{component.name}
        Made from: #{(parts + lines).join(", ").presence || "(no ingredients listed)"}
        Steps:
        #{component.steps.map { |step| "- #{step.instructions}" }.join("\n")}
      TEXT
    end
end
