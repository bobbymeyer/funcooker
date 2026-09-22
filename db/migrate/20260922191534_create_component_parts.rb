class CreateComponentParts < ActiveRecord::Migration[8.1]
  def change
    create_table :component_parts do |t|
      t.references :parent, null: false, foreign_key: { to_table: :components }
      t.references :child, null: false, foreign_key: { to_table: :components }
      t.decimal :quantity
      t.string :unit
      t.references :step, foreign_key: true

      t.timestamps
    end
    add_index :component_parts, [ :parent_id, :child_id ], unique: true
  end
end
