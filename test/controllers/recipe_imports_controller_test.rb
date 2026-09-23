require "test_helper"

class RecipeImportsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_recipe_import_path
    assert_response :success
  end

  test "create enqueues the import and shows it" do
    assert_enqueued_jobs 1, only: RecipeImportJob do
      post recipe_imports_path, params: { recipe_import: { source_url: "https://food.test/chili", source_text: "" } }
    end

    import = RecipeImport.last
    assert_redirected_to import
    follow_redirect!
    assert_select "p", /Importing/
  end

  test "create with a named dish" do
    post recipe_imports_path, params: { recipe_import: { source_url: "", source_text: "", dish_name: "eggs and toast", sophistication: "home_cook" } }

    assert_redirected_to RecipeImport.last
    assert_equal "eggs and toast", RecipeImport.last.dish_name
    assert RecipeImport.last.home_cook?
    follow_redirect!
    assert_select "p.lede", "eggs and toast, by a home cook"
  end

  test "the form offers every level" do
    get new_recipe_import_path
    assert_select "select#recipe_import_sophistication option", [ "divorced dad", "home cook", "Michelin chef" ].size
    assert_select "option[selected]", "divorced dad"
    assert_select "label[for=recipe_import_sophistication]", "Written by"
  end

  test "create with no source re-renders the form" do
    post recipe_imports_path, params: { recipe_import: { source_url: "", source_text: "" } }
    assert_response :unprocessable_entity
  end

  test "a finished import goes to its component" do
    component = Component.create!(name: "Toast")
    import = RecipeImport.create!(source_text: "Toast", status: :succeeded, component:)

    get recipe_import_path(import)
    assert_redirected_to component
  end

  test "a failed import shows why" do
    import = RecipeImport.create!(source_text: "Toast", status: :failed, error: "No recipe found")

    get recipe_import_path(import)
    assert_select "p.errors", "No recipe found"
  end

  test "index and destroy, keeping the recipe" do
    component = Component.create!(name: "Toast")
    import = RecipeImport.create!(dish_name: "toast", status: :succeeded, component:)

    get recipe_imports_path
    assert_select "a", "Toast"

    delete recipe_import_path(import)
    assert_redirected_to recipe_imports_path
    assert_not RecipeImport.exists?(import.id)
    assert Component.exists?(component.id)
  end

  test "deleting a recipe keeps its import, without it" do
    component = Component.create!(name: "Toast")
    import = RecipeImport.create!(dish_name: "toast", status: :succeeded, component:)

    component.destroy!
    assert_nil import.reload.component
  end
end
