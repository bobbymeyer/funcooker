# Asks the model how a recipe breaks down. Its ingredient lines are given ids
# (i1, i2, …) and the model can only refer to those, so it cannot invent an
# ingredient; an existing component can only be named from the candidates.
#
#   { verdict:, reason:, caveats: [...],
#     components: [{ name:, existing:, servings:, ingredients: [...], steps: [...] }],
#     ingredients: [{ line:, amount:, unit:, note: }], steps: [{ ..., uses: [...] }] }
#
# The verdict is the model's judgement first: decompose, atomic (nothing
# worth making on its own), or borderline (a part could be made apart, at a
# cost to the dish, which the caveats say).
class Decomposition::Plan
  CANDIDATE_LIMIT = 300

  def initialize(component, lines:, candidates:)
    @component, @lines, @candidates = component, lines, candidates.first(CANDIDATE_LIMIT)
  end

  def call
    Llm.extract(schema:, input:, instructions: <<~TEXT).deep_symbolize_keys
      You break a recipe into its components: the parts that can be made ahead on their own and reused in other dishes, like a sauce, a marinade, a dressing, a spice mix, cooked rice or a dough. Then you rewrite the recipe to use them.
      The recipe is written for one adult. Keep its amounts.

      Judge first, and be honest about it. Making something apart is only worth it when the dish is as good for it.
      - verdict: decompose when it has parts that can be made ahead with nothing lost.
      - verdict: atomic when nothing in it can meaningfully be made on its own: it is already one thing, or its parts only work cooked together (a vinaigrette, a stir-fry where everything goes in one pan, an omelette). Then leave components, ingredients and steps empty.
      - verdict: borderline when a part could be made apart but the dish suffers for it. For example, the meat for a bolognese could be braised on its own, but the sauce then loses the fond and the depth it builds cooking with the meat. Give the plan anyway, and list what is lost.
      - reason: one or two plain sentences on why.
      - caveats: for borderline, each thing the dish loses by splitting it, one per entry. Otherwise empty.

      - components: each part worth making on its own. Leave out anything that is only an ingredient, or only assembly.
        - When a known component below is the same thing or very close to it, reuse it: set existing to its name exactly, servings to how many of its servings this dish uses for one adult (usually 1), ingredients to the recipe's lines it takes the place of, and steps empty. Known components are also written for one adult.
        - Otherwise existing is null: give it a plain name, its ingredients and its steps, and servings 1.
        - ingredients: which of the recipe's ingredient lines go into it, by line id, with the amount it needs. A line can be split between components and the dish, as long as the amounts add up to the line's amount.
      - ingredients: the lines the dish uses directly, not inside any component.
      - steps: the dish's own steps, rewritten to use the components by name instead of repeating how they are made. uses: the names of the components and the ids of the ingredient lines each step uses.

      For every step:
      - phase: prep for anything that can be done ahead, which includes making any component; plate for what happens at serving time.
      - mode: active when it needs hands or attention; passive when it only waits, like marinating, simmering unattended, baking or resting.
      - duration_minutes: your estimate, or null.

      Use every ingredient line somewhere. Invent no ingredients.

      Known components:
      #{known_components}
    TEXT
  end

  private
    def input
      <<~TEXT
        Recipe: #{@component.name}

        Ingredient lines:
        #{@lines.each_with_index.map { |line, index| "#{line_id(index)}: #{describe(line)}" }.join("\n")}

        Steps:
        #{@component.steps.map { |step| "#{step.position}. #{step.instructions}" }.join("\n")}
      TEXT
    end

    def known_components
      return "none yet" if @candidates.empty?

      @candidates.map do |candidate|
        "- #{candidate.name}: #{candidate.component_ingredients.map { |line| (line.ingredient || line.ingredient_family).name }.join(", ")}"
      end.join("\n")
    end

    def describe(line)
      name = line.ingredient ? line.ingredient.name : "any #{line.ingredient_family.name}"
      [ line.quantity && line.quantity.to_s("F").sub(/\.0\z/, ""), line.unit, name, (", #{line.note}" if line.note) ].compact.join(" ").sub(" ,", ",")
    end

    def line_id(index) = "i#{index + 1}"

    def schema
      line_ref = {
        type: "object",
        properties: {
          line: { type: "string", enum: @lines.each_index.map { |index| line_id(index) } },
          amount: { type: [ "number", "null" ] },
          unit: { type: [ "string", "null" ] },
          note: { type: [ "string", "null" ] }
        },
        required: %w[ line amount unit note ],
        additionalProperties: false
      }
      step = {
        type: "object",
        properties: {
          instructions: { type: "string" },
          phase: { type: "string", enum: %w[ prep plate ] },
          mode: { type: "string", enum: %w[ active passive ] },
          duration_minutes: { type: [ "integer", "null" ] }
        },
        required: %w[ instructions phase mode duration_minutes ],
        additionalProperties: false
      }
      dish_step = step.merge(
        properties: step[:properties].merge(uses: { type: "array", items: { type: "string" } }),
        required: step[:required] + %w[ uses ]
      )
      existing = @candidates.any? ? { anyOf: [ { type: "string", enum: @candidates.map(&:name).uniq }, { type: "null" } ] } : { type: "null" }

      {
        type: "object",
        properties: {
          verdict: { type: "string", enum: %w[ decompose atomic borderline ] },
          reason: { type: "string" },
          caveats: { type: "array", items: { type: "string" } },
          components: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" },
                existing:,
                servings: { type: "number" },
                ingredients: { type: "array", items: line_ref },
                steps: { type: "array", items: step }
              },
              required: %w[ name existing servings ingredients steps ],
              additionalProperties: false
            }
          },
          ingredients: { type: "array", items: line_ref },
          steps: { type: "array", items: dish_step }
        },
        required: %w[ verdict reason caveats components ingredients steps ],
        additionalProperties: false
      }
    end
end
