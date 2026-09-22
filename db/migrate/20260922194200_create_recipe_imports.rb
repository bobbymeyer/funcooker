class CreateRecipeImports < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_imports do |t|
      t.string :source_url
      t.text :source_text
      t.integer :status, null: false, default: 0
      t.text :error
      t.references :component, foreign_key: true

      t.timestamps
    end
  end
end
