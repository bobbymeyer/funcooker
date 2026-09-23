# Asks the model how long a component keeps once made, stored the usual way
# for it, how long it keeps frozen, and how it knows. Conservative, since the
# answers set when prepped and frozen stock expire.
module Component::ShelfLife
  SCHEMA = {
    type: "object",
    properties: {
      days: { type: "integer" },
      storage: { type: "string" },
      basis: { type: "string" },
      freezer_days: { type: "integer" },
      freezer_basis: { type: "string" }
    },
    required: %w[ days storage basis freezer_days freezer_basis ],
    additionalProperties: false
  }.freeze

  extend self

  def estimate(component)
    reply = Llm.extract(schema: SCHEMA, input: describe(component), instructions: <<~TEXT)
      Estimate how many whole days this keeps once it is made, stored the usual way for it: a sealed container in the fridge for most cooked food and sauces, the pantry for a dry spice mix. Follow common food-safety guidance and stay on the conservative side: cooked meat, poultry and fish keep 3 days, cooked grains and most cooked vegetables 4, vinaigrettes and pickles longer.
      - days: the whole number of days.
      - storage: where it is kept, in a few words.
      - basis: the rule you applied, in a few words.
      Then estimate how many whole days it keeps at best quality frozen in a sealed container, made and frozen the same day. Most soups, stews, braises, sauces, cooked grains, beans and stocks keep about 90 days; cooked meat about 60. Give 0 when freezing ruins it: dressed salads, raw-vegetable salads, emulsified sauces like mayonnaise or hollandaise, dishes built on fresh crisp textures, cooked eggs, cream-based sauces that split.
      - freezer_days: the whole number of days, or 0.
      - freezer_basis: the rule you applied, or what freezing ruins, in a few words.
    TEXT

    days = reply["days"].to_i
    raise Llm::Error, "The model gave #{reply["days"].inspect} days" unless days.positive?

    freezer_days = reply["freezer_days"]
    raise Llm::Error, "The model gave #{freezer_days.inspect} freezer days" unless freezer_days.is_a?(Integer) && freezer_days >= 0

    {
      days:, note: [ reply["storage"], reply["basis"] ].map { |part| part.to_s.squish }.compact_blank.join("; ").truncate(200),
      freezer_days:, freezer_note: reply["freezer_basis"].to_s.squish.truncate(200).presence
    }
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
