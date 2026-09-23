class CreateDecompositions < ActiveRecord::Migration[8.1]
  def change
    create_table :decompositions do |t|
      t.references :component, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.text :error
      t.json :original

      t.timestamps
    end
  end
end
