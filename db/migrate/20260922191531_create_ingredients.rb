class CreateIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredients do |t|
      t.string :name, null: false
      t.string :category
      t.string :default_unit
      t.references :ingredient_family, foreign_key: true

      t.timestamps
    end
    add_index :ingredients, :name, unique: true
  end
end
