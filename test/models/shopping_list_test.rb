require "test_helper"

class ShoppingListTest < ActiveSupport::TestCase
  setup do
    HouseholdMember.create!(name: "Bobby")
    HouseholdMember.create!(name: "kid", portion: 0.5)

    @beef = Ingredient.create!(name: "ground beef", default_unit: "lb", pack_size: 1)
    @tortilla = Ingredient.create!(name: "corn tortilla")
    @salt = Ingredient.create!(name: "salt")
    @alliums = IngredientFamily.create!(name: "alliums")
    @onion = Ingredient.create!(name: "red onion", ingredient_family: @alliums)

    @filling = Component.create!(name: "seasoned beef")
    @filling.component_ingredients.create!(ingredient: @beef, quantity: 0.25, unit: "lb")
    @filling.component_ingredients.create!(ingredient: @salt, note: "to taste")
    @filling.component_ingredients.create!(ingredient_family: @alliums, quantity: 0.5)

    @tacos = Component.create!(name: "tacos")
    @tacos.component_ingredients.create!(ingredient: @tortilla, quantity: 3)
    ComponentPart.create!(parent: @tacos, child: @filling, quantity: 1, unit: "serving")

    @tuesday = ScheduleEntry.create!(served_on: Date.current, dish: @tacos)
    @friday = ScheduleEntry.create!(served_on: Date.current + 3, dish: @tacos)
  end

  test "needs are scaled to each meal's servings and rounded up to packs and whole counts" do
    items = list.items.index_by(&:name)

    beef = items.fetch("ground beef")
    assert_equal 0.75, beef.needed, "0.25 lb x 1.5 servings x 2 meals"
    assert_equal [ 1, 1 ], [ beef.packs, beef.pack ]
    assert_equal "ground beef, 1 × 1 lb", beef.title

    tortilla = items.fetch("corn tortilla")
    assert_equal 9, tortilla.to_buy, "3 x 1.5 x 2"
    assert_equal "corn tortilla, 9", tortilla.title

    onion = items.fetch("any alliums")
    assert_equal 2, onion.to_buy, "0.5 x 3 = 1.5, bought whole"
  end

  test "stock on hand is taken off, named ingredients before families" do
    StockItem.create!(stockable: @beef, kind: :raw, quantity: 0.5, unit: "lb")
    StockItem.create!(stockable: @onion, kind: :raw, quantity: 5)

    items = list.items.index_by(&:name)

    assert_equal 0.25, items.fetch("ground beef").to_buy
    assert_not items.key?("any alliums"), "5 red onions cover 1.5"
  end

  test "an ingredient to taste is listed only when there is none" do
    assert list.items.map(&:name).include?("salt")
    assert_equal "salt", list.items.find { |item| item.name == "salt" }.title

    StockItem.create!(stockable: @salt, kind: :raw, quantity: 1, unit: "box")
    assert_not ShoppingList.new.items.map(&:name).include?("salt")
  end

  test "prepped components cover their meals first, in date order" do
    StockItem.create!(stockable: @filling, kind: :prepped, quantity: 1.5, unit: "serving")

    beef = list.items.find { |item| item.name == "ground beef" }

    assert_equal 0.375, beef.needed, "Tuesday's filling is prepped; Friday's is not"
    assert_equal [ @friday ], beef.meals
  end

  test "a frozen dish covers its meal whole; frozen components count as prepped" do
    StockItem.create!(stockable: @tacos, kind: :freezer, quantity: 1.5, unit: "serving")
    StockItem.create!(stockable: @filling, kind: :freezer, quantity: 1.5, unit: "serving")

    assert_empty list.items.map(&:name) & [ "ground beef" ], "Tuesday is frozen tacos; Friday's filling is frozen"
    assert_equal [ @friday ], list.items.find { |item| item.name == "corn tortilla" }.meals
  end

  test "stock in another unit is noted, not converted" do
    StockItem.create!(stockable: @beef, kind: :raw, quantity: 2, unit: "kg")

    beef = list.items.find { |item| item.name == "ground beef" }

    assert_equal 0.75, beef.to_buy
    assert_equal "stock is in kg, not compared", beef.note
  end

  test "only planned meals in the window count" do
    @friday.skipped!
    ScheduleEntry.create!(served_on: Date.current + 20, dish: @tacos)

    assert_equal 0.375, list.items.find { |item| item.name == "ground beef" }.needed
  end

  test "each item's notes say what it is for" do
    tortilla = list.items.find { |item| item.name == "corn tortilla" }

    assert_match(/\Afor tacos \(\w{3} \d+ \w{3}\) and tacos/, tortilla.notes)
    assert_match "need 9, have 0", tortilla.notes
  end

  private
    def list = ShoppingList.new(days: 7)
end
