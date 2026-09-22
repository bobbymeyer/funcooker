class CreateFoodNeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :food_needs do |t|
      t.references :household_member, null: false, foreign_key: true
      t.references :subject, polymorphic: true, null: false
      t.integer :tier, null: false, default: 0

      t.timestamps
    end
  end
end
