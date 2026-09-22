class CreateComponents < ActiveRecord::Migration[8.1]
  def change
    create_table :components do |t|
      t.string :name, null: false
      t.text :description
      t.string :source_url

      t.timestamps
    end
  end
end
