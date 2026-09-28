class AddCookbookPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :recipe_imports, :source_note, :string
    add_column :recipe_imports, :photo_recipe_name, :string
    add_column :components, :source_note, :string
  end
end
