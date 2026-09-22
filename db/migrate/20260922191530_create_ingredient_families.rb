class CreateIngredientFamilies < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredient_families do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :ingredient_families, :name, unique: true
  end
end
