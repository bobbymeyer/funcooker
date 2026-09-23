class AddPackSizeToIngredients < ActiveRecord::Migration[8.1]
  def change
    add_column :ingredients, :pack_size, :decimal
  end
end
