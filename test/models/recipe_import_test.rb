require "test_helper"

class RecipeImportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  CHILI_INGREDIENTS = {
    ingredients: [
      { amount: 2, unit: nil, ingredient: "red onion", note: "finely diced" },
      { amount: 1.5, unit: "lb", ingredient: "ground beef", note: nil },
      { amount: nil, unit: nil, ingredient: "salt", note: "to taste" }
    ]
  }.freeze

  test "a page with JSON-LD is read directly, with only its ingredient lines sent to the model" do
    stub_page "https://food.test/chili", "recipe_with_json_ld.html"
    stub_llm CHILI_INGREDIENTS

    import = RecipeImport.create!(source_url: "https://food.test/chili")
    import.process

    assert import.succeeded?
    component = import.component
    assert_equal "Weeknight Chili", component.name
    assert_equal "A fast chili & nothing fancy.", component.description
    assert_equal "https://food.test/chili", component.source_url
    assert_equal [ "Soften the onions.", "Brown the beef.", "Season and simmer for 30 minutes." ], component.steps.map(&:instructions)
    assert_equal [ 1, 2, 3 ], component.steps.map(&:position)

    beef = component.component_ingredients.find_by!(ingredient: Ingredient.find_by!(name: "ground beef"))
    assert_equal 1.5, beef.quantity
    assert_equal "lb", beef.unit

    assert_requested :post, LlmStubs::LLM_URL do |request|
      body = JSON.parse(request.body)
      body["messages"].last["content"] == "2 red onions, finely diced\n1 1/2 lb ground beef\nsalt to taste" &&
        body.dig("response_format", "type") == "json_schema" &&
        body.dig("chat_template_kwargs", "enable_thinking") == false
    end
  end

  test "a page without JSON-LD sends its readable text to the model" do
    stub_page "https://food.test/salad", "recipe_without_json_ld.html"
    stub_llm name: "Tomato Salad", description: nil,
      ingredients: [ { amount: 2, unit: nil, ingredient: "tomato", note: "sliced" } ],
      steps: [ "Slice the tomatoes.", "Dress with oil and salt." ]

    import = RecipeImport.create!(source_url: "https://food.test/salad")
    import.process

    assert import.succeeded?
    assert_equal "Tomato Salad", import.component.name
    assert_requested :post, LlmStubs::LLM_URL do |request|
      text = JSON.parse(request.body)["messages"].last["content"]
      text.include?("Slice the tomatoes.") && !text.include?("tracking") && !text.include?("Copyright")
    end
  end

  test "pasted text goes to the model" do
    stub_llm name: "Toast", description: nil,
      ingredients: [ { amount: 1, unit: "slice", ingredient: "bread", note: nil } ],
      steps: [ "Toast it." ]

    import = RecipeImport.create!(source_text: "Toast: 1 slice bread. Toast it.")
    import.process

    assert import.succeeded?
    assert_equal [ "bread" ], import.component.component_ingredients.map { |line| line.ingredient.name }
  end

  test "a simple dish is written by the model, for the household" do
    2.times { |i| HouseholdMember.create!(name: "member #{i}") }
    stub_llm name: "Pasta with red sauce", description: "should be dropped",
      ingredients: [
        { amount: 1, unit: "lb", ingredient: "dried pasta", note: nil },
        { amount: 1, unit: "jar", ingredient: "marinara sauce", note: nil }
      ],
      steps: [ "Boil the pasta.", "Heat the sauce and pour it over." ]

    import = RecipeImport.create!(simple_dish: "pasta and red sauce, store-bought noodles and sauce")
    import.process

    assert import.succeeded?
    assert_equal "Pasta with red sauce", import.component.name
    assert_nil import.component.description
    assert_nil import.component.source_url
    assert_equal [ "dried pasta", "marinara sauce" ], import.component.component_ingredients.map { |line| line.ingredient.name }

    assert_requested :post, LlmStubs::LLM_URL do |request|
      system, user = JSON.parse(request.body)["messages"].map { |message| message["content"] }
      user == "pasta and red sauce, store-bought noodles and sauce" &&
        system.include?("simplest possible recipe") && system.include?("for 2 people")
    end
  end

  test "a simple dish with nobody in the household is for one person" do
    stub_llm name: "Toast", description: nil, ingredients: [ { amount: 1, unit: "slice", ingredient: "bread", note: nil } ], steps: [ "Toast it." ]

    RecipeImport.create!(simple_dish: "toast").process

    assert_requested :post, LlmStubs::LLM_URL do |request|
      JSON.parse(request.body)["messages"].first["content"].include?("for 1 person")
    end
  end

  test "ingredients are shared across imports by name" do
    existing = Ingredient.create!(name: "bread")
    stub_llm name: "Toast", description: nil,
      ingredients: [ { amount: 1, unit: nil, ingredient: "Bread", note: nil } ], steps: [ "Toast it." ]

    import = RecipeImport.create!(source_text: "Toast")
    import.process

    assert_equal existing, import.component.component_ingredients.sole.ingredient
  end

  test "an imported recipe is a dish" do
    stub_llm name: "Toast", description: nil, ingredients: [], steps: [ "Toast it." ]

    import = RecipeImport.create!(source_text: "Toast it.")
    import.process

    assert import.component.dish?
  end

  test "text with no recipe fails" do
    stub_llm name: "", description: nil, ingredients: [], steps: []

    import = RecipeImport.create!(source_text: "Just a shopping list rant.")
    import.process

    assert import.failed?
    assert_equal "No recipe found", import.error
    assert_nil import.component
  end

  test "an unreachable model fails the import with the reason" do
    stub_request(:post, LlmStubs::LLM_URL).to_return(status: 503, body: "Loading model")

    import = RecipeImport.create!(source_text: "Toast it.")
    import.process

    assert import.failed?
    assert_match "503", import.error
  end

  test "a page that errors fails the import" do
    stub_request(:get, "https://food.test/gone").to_return(status: 404)

    import = RecipeImport.create!(source_url: "https://food.test/gone")
    import.process

    assert import.failed?
    assert_equal "https://food.test/gone answered 404", import.error
  end

  test "redirects are followed" do
    stub_request(:get, "https://food.test/old").to_return(status: 301, headers: { "Location" => "/chili" })
    stub_page "https://food.test/chili", "recipe_with_json_ld.html"
    stub_llm CHILI_INGREDIENTS

    import = RecipeImport.create!(source_url: "https://food.test/old")
    import.process

    assert import.succeeded?
  end

  test "needs exactly one source" do
    assert_not RecipeImport.new.valid?
    assert_not RecipeImport.new(source_url: "https://a.test", source_text: "toast").valid?
    assert_not RecipeImport.new(source_text: "toast", simple_dish: "toast").valid?
    assert RecipeImport.new(simple_dish: "eggs and toast").valid?
    assert_not RecipeImport.new(source_url: "ftp://a.test/recipe").valid?
    assert RecipeImport.new(source_url: " https://a.test/recipe ").valid?
  end

  test "creating an import enqueues it" do
    assert_enqueued_with(job: RecipeImportJob) { RecipeImport.create!(source_text: "Toast it.") }
  end

  private
    def stub_page(url, fixture)
      stub_request(:get, url).to_return(status: 200, body: file_fixture(fixture).read, headers: { "Content-Type" => "text/html" })
    end
end
