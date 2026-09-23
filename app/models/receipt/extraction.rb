# Reads a receipt, as text or a photo, into:
#
#   { store:, purchased_on:, lines: [{ description:, item:, quantity:, unit:, food:, shelf_life_days: }] }
#
# Each item is named as an ingredient, reusing a known ingredient's name when
# it is the same thing, so lines match what is already in the library.
module Receipt::Extraction
  LINE = {
    type: "object",
    properties: {
      description: { type: "string" },
      item: { type: "string" },
      quantity: { type: [ "number", "null" ] },
      unit: { type: [ "string", "null" ] },
      food: { type: "boolean" },
      shelf_life_days: { type: [ "integer", "null" ] }
    },
    required: %w[ description item quantity unit food shelf_life_days ],
    additionalProperties: false
  }.freeze

  RECEIPT = {
    type: "object",
    properties: {
      store: { type: [ "string", "null" ] },
      purchased_on: { type: [ "string", "null" ] },
      lines: { type: "array", items: LINE }
    },
    required: %w[ store purchased_on lines ],
    additionalProperties: false
  }.freeze

  extend self

  def read(text:, image:, known:)
    reply = Llm.extract(schema: RECEIPT, image:, input: text || "The receipt is in the photo.", instructions: <<~TEXT)
      Read the grocery receipt the user gives you.
      - store: the store's name, or null.
      - purchased_on: the date of purchase as YYYY-MM-DD, or null.
      - lines: one per item bought, in order. Leave out totals, subtotals, tax, payments, change, discounts, coupons, deposits and bag fees.

      For each line:
      - description: the line as printed.
      - item: what it is, as a plain ingredient name: lowercase, singular, without brand, size or packaging. "BNLS SKNLS CHKN BRST" is "chicken breast". When it is the same thing as a known ingredient below, use that name exactly.
      - quantity: the total amount bought, in unit. "2 @ MILK 1 GAL" is 2 gal. A weighed item is its weight: "BANANAS 2.31 lb" is 2.31 lb. A counted item is its count: a dozen eggs is 12. null when you cannot tell.
      - unit: lowercase and abbreviated: g, kg, ml, l, oz, lb, gal, qt, pt. null for a count.
      - food: false for anything that is not food or drink, like paper towels, soap or batteries.
      - shelf_life_days: how many days it typically keeps at home, stored the usual way: fridge for dairy, meat and most produce, pantry for dry goods. null when it is not food.

      Known ingredients: #{known.any? ? known.join(", ") : "none yet"}.
    TEXT

    {
      store: reply["store"].to_s.squish.presence,
      purchased_on: (Date.iso8601(reply["purchased_on"]) rescue nil),
      lines: Array(reply["lines"]).filter_map { |line| normalize(line) }
    }
  end

  private
    def normalize(line)
      return if line["description"].blank? && line["item"].blank?

      {
        description: line["description"].to_s.squish.presence || line["item"].to_s.squish,
        item: line["item"].to_s.squish.downcase.presence,
        quantity: line["quantity"],
        unit: line["unit"].to_s.squish.presence,
        food: line["food"] != false,
        shelf_life_days: (line["shelf_life_days"] if line["shelf_life_days"].to_i.positive?)
      }
    end
end
