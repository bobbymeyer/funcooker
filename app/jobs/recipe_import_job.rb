class RecipeImportJob < ApplicationJob
  def perform(recipe_import)
    recipe_import.process
  end
end
