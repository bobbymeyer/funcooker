class AddSimpleDishToRecipeImports < ActiveRecord::Migration[8.1]
  def change
    add_column :recipe_imports, :simple_dish, :string
  end
end
