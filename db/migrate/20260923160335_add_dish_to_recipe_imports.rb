class AddDishToRecipeImports < ActiveRecord::Migration[8.1]
  def change
    add_column :recipe_imports, :dish_name, :string
    add_column :recipe_imports, :sophistication, :integer, null: false, default: 0
  end
end
