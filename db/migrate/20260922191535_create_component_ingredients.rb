class CreateComponentIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :component_ingredients do |t|
      t.references :component, null: false, foreign_key: true
      t.references :ingredient, foreign_key: true
      t.references :ingredient_family, foreign_key: true
      t.decimal :quantity
      t.string :unit
      t.string :note
      t.references :step, foreign_key: true

      t.timestamps
    end
  end
end
