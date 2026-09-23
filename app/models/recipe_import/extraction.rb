# Turns a source into the recipe shape an import builds from:
#
#   { name:, description:, steps: [String], ingredients: [{ amount:, unit:, ingredient:, note: }] }
#
# JSON-LD is read directly, and only its ingredient lines go to the model to be
# parsed. Anything else goes to the model whole. A simple dish has no source:
# the model writes the plainest version of it.
module RecipeImport::Extraction
  INGREDIENT = {
    type: "object",
    properties: {
      amount: { type: [ "number", "null" ] },
      unit: { type: [ "string", "null" ] },
      ingredient: { type: "string" },
      note: { type: [ "string", "null" ] }
    },
    required: %w[ amount unit ingredient note ],
    additionalProperties: false
  }.freeze

  INGREDIENTS = {
    type: "object",
    properties: { ingredients: { type: "array", items: INGREDIENT } },
    required: %w[ ingredients ],
    additionalProperties: false
  }.freeze

  RECIPE = {
    type: "object",
    properties: {
      name: { type: "string" },
      description: { type: [ "string", "null" ] },
      ingredients: { type: "array", items: INGREDIENT },
      steps: { type: "array", items: { type: "string" } }
    },
    required: %w[ name description ingredients steps ],
    additionalProperties: false
  }.freeze

  INGREDIENT_FIELDS = <<~TEXT
    For each ingredient:
    - ingredient: the ingredient itself, lowercase and singular, without quantity, preparation or brand. "red onion", not "2 red onions, finely diced".
    - amount: a number. Write fractions as decimals: "1 1/2" is 1.5. For a range, the low end, and put the range in note. null when there is no amount, as in "salt to taste".
    - unit: lowercase and abbreviated: g, kg, ml, l, tsp, tbsp, cup, oz, lb, or the recipe's own word ("clove", "can", "bunch"). null for a plain count, as in "2 eggs".
    - note: preparation and anything else on the line, as written. null when there is nothing else.
  TEXT

  INGREDIENT_RULES = <<~TEXT
    #{INGREDIENT_FIELDS}
    Keep every line, in order. Invent nothing.
  TEXT

  extend self

  def from_json_ld(recipe)
    return unless recipe

    {
      name: plain(recipe["name"]),
      description: plain(recipe["description"]).presence,
      steps: steps(recipe["recipeInstructions"]),
      ingredients: ingredients(Array(recipe["recipeIngredient"] || recipe["ingredients"]).map { |line| plain(line) }.compact_blank)
    }
  end

  def from_text(text)
    reply = Llm.extract(schema: RECIPE, input: text, instructions: <<~TEXT)
      Extract the recipe from the text the user gives you. Copy it; do not invent or improve anything.
      - name: the recipe's title.
      - description: its short introduction, if it has one, else null.
      - steps: each instruction step in order, as written, without numbering.
      If the text holds no recipe, return an empty name, ingredients and steps.

      #{INGREDIENT_RULES}
    TEXT

    {
      name: reply["name"].to_s.squish,
      description: reply["description"].presence,
      steps: Array(reply["steps"]).map(&:squish).compact_blank,
      ingredients: normalize(reply["ingredients"])
    }
  end

  def simplest(dish, servings:)
    reply = Llm.extract(schema: RECIPE, input: dish, instructions: <<~TEXT)
      The user names a dish too simple for a cookbook, like pasta with jarred sauce or eggs and toast. Write the simplest possible recipe for it, for #{servings} #{"person".pluralize(servings)}. It is for keeping track of ingredients in a home kitchen, not for impressing anyone.
      - Use only what the dish cannot be made without, plus anything the user names. No garnishes, no optional extras, no seasoning the user did not ask for beyond salt where cooking needs it.
      - Anything the user says is store-bought is a single ingredient, used as it comes: "jarred marinara sauce", never a sauce made from scratch.
      - As few steps as possible, each one short and plain. No tips, no variations.
      - name: the plain name of the dish.
      - description: null.
      Do not get clever or fancy.

      #{INGREDIENT_FIELDS}
    TEXT

    {
      name: reply["name"].to_s.squish,
      description: nil,
      steps: Array(reply["steps"]).map(&:squish).compact_blank,
      ingredients: normalize(reply["ingredients"])
    }
  end

  private
    def ingredients(lines)
      return [] if lines.empty?

      reply = Llm.extract(schema: INGREDIENTS, input: lines.join("\n"), instructions: <<~TEXT)
        The user gives you a recipe's ingredient list, one ingredient per line. Parse each line.

        #{INGREDIENT_RULES}
      TEXT
      normalize(reply["ingredients"])
    end

    def normalize(lines)
      Array(lines).filter_map do |line|
        next if line["ingredient"].blank?

        line.symbolize_keys.slice(:amount, :unit, :ingredient, :note).transform_values { |value| value.is_a?(String) ? value.squish.presence : value }
      end
    end

    # HowToStep, HowToSection and plain strings, nested any way a site likes.
    def steps(node)
      case node
      when String then node.split(/\n+/).map { |line| plain(line) }.compact_blank
      when Array then node.flat_map { |item| steps(item) }
      when Hash then node["itemListElement"] ? steps(node["itemListElement"]) : steps(node["text"] || node["name"])
      else []
      end
    end

    def plain(value)
      Nokogiri::HTML.fragment(value.to_s).text.squish
    end
end
