# Turns a source into the recipe shape an import builds from:
#
#   { name:, description:, servings:, steps: [String], ingredients: [{ amount:, unit:, ingredient:, note: }] }
#
# servings is how many adult portions the amounts make, as the source wrote
# them. The import divides by it; the model never does the arithmetic.
#
# JSON-LD is read directly, and only its ingredient lines go to the model to be
# parsed. Anything else goes to the model whole. A named dish has no source:
# the model writes it, at the sophistication asked for.
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
    properties: { servings: { type: "number" }, ingredients: { type: "array", items: INGREDIENT } },
    required: %w[ servings ingredients ],
    additionalProperties: false
  }.freeze

  RECIPE = {
    type: "object",
    properties: {
      name: { type: "string" },
      description: { type: [ "string", "null" ] },
      servings: { type: "number" },
      ingredients: { type: "array", items: INGREDIENT },
      steps: { type: "array", items: { type: "string" } }
    },
    required: %w[ name description servings ingredients steps ],
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
    Keep every line, in order, with its amount as written. Do not scale anything. Invent nothing.
  TEXT

  SERVINGS_RULE = <<~TEXT
    - servings: how many adult portions the recipe makes as written. Read it from the yield: "Serves 4" is 4, "4-6 servings" is 4. When the yield is in pieces or a container ("24 cookies", "1 loaf"), estimate the adult portions. When there is no yield, estimate from the amounts. Always a number above 0.
  TEXT

  extend self

  def from_json_ld(recipe)
    return unless recipe

    lines = Array(recipe["recipeIngredient"] || recipe["ingredients"]).map { |line| plain(line) }.compact_blank
    yields = Array(recipe["recipeYield"]).map { |value| plain(value) }.compact_blank.join(", ")

    {
      name: plain(recipe["name"]),
      description: plain(recipe["description"]).presence,
      steps: steps(recipe["recipeInstructions"])
    }.merge(ingredients(lines, yields:))
  end

  def from_text(text)
    reply = Llm.extract(schema: RECIPE, input: text, instructions: <<~TEXT)
      Extract the recipe from the text the user gives you. Copy it; do not invent or improve anything.
      - name: the recipe's title.
      - description: its short introduction, if it has one, else null.
      - steps: each instruction step in order, as written, without numbering.
      #{SERVINGS_RULE}
      If the text holds no recipe, return an empty name, ingredients and steps, and 1 serving.

      #{INGREDIENT_RULES}
    TEXT

    {
      name: reply["name"].to_s.squish,
      description: reply["description"].presence,
      servings: reply["servings"],
      steps: Array(reply["steps"]).map(&:squish).compact_blank,
      ingredients: normalize(reply["ingredients"])
    }
  end

  # How far a generated recipe goes, from the least a dish can be to a chef's
  # version of it. Every level writes for one adult.
  SOPHISTICATION = {
    "divorced_dad" => <<~TEXT,
      Write the simplest possible recipe for it. It is for keeping track of ingredients in a home kitchen, not for impressing anyone.
      - Use only what the dish cannot be made without, plus anything the user names. No garnishes, no optional extras, no seasoning the user did not ask for beyond salt where cooking needs it.
      - Use store-bought versions wherever a store sells one.
      - As few steps as possible, each one short and plain. No tips, no variations.
      Do not get clever or fancy.
    TEXT
    "home_cook" => <<~TEXT,
      Write the recipe the way a competent home cook would make it on a weeknight.
      - Everyday supermarket ingredients. Make the parts that are quick to make from scratch; buy the rest.
      - Basic seasoning and an aromatic or two where they make a real difference, and no more.
      - Plain steps a home kitchen can follow, with no special equipment.
    TEXT
    "michelin_chef" => <<~TEXT
      Write the recipe the way a Michelin-starred chef would make it.
      - Make every part from scratch, with the best ingredients for it.
      - Precise amounts, refined technique, and a finished, plated dish.
      - Every step a chef would take, in order, each one specific.
    TEXT
  }.freeze

  def generate(dish, sophistication:)
    reply = Llm.extract(schema: RECIPE, input: dish, instructions: <<~TEXT)
      The user names a dish. #{SOPHISTICATION.fetch(sophistication)}
      Anything the user says is store-bought stays store-bought: a single ingredient, used as it comes.
      Write it for one adult.
      - name: the plain name of the dish.
      - description: null.
      - servings: 1.

      #{INGREDIENT_FIELDS}
    TEXT

    {
      name: reply["name"].to_s.squish,
      description: nil,
      servings: 1,
      steps: Array(reply["steps"]).map(&:squish).compact_blank,
      ingredients: normalize(reply["ingredients"])
    }
  end

  private
    def ingredients(lines, yields:)
      return { servings: 1, ingredients: [] } if lines.empty?

      input = "Yield: #{yields.presence || "not given"}\n\n#{lines.join("\n")}"
      reply = Llm.extract(schema: INGREDIENTS, input:, instructions: <<~TEXT)
        The user gives you a recipe's yield, then its ingredient list, one ingredient per line. Parse each line.
        #{SERVINGS_RULE}
        #{INGREDIENT_RULES}
      TEXT
      { servings: reply["servings"], ingredients: normalize(reply["ingredients"]) }
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
