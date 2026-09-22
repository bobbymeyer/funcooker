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
end
