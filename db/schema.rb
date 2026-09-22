# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_22_194200) do
  create_table "component_ingredients", force: :cascade do |t|
    t.integer "component_id", null: false
    t.datetime "created_at", null: false
    t.integer "ingredient_family_id"
    t.integer "ingredient_id"
    t.string "note"
    t.decimal "quantity"
    t.integer "step_id"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["component_id"], name: "index_component_ingredients_on_component_id"
    t.index ["ingredient_family_id"], name: "index_component_ingredients_on_ingredient_family_id"
    t.index ["ingredient_id"], name: "index_component_ingredients_on_ingredient_id"
    t.index ["step_id"], name: "index_component_ingredients_on_step_id"
  end

  create_table "component_parts", force: :cascade do |t|
    t.integer "child_id", null: false
    t.datetime "created_at", null: false
    t.integer "parent_id", null: false
    t.decimal "quantity"
    t.integer "step_id"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["child_id"], name: "index_component_parts_on_child_id"
    t.index ["parent_id", "child_id"], name: "index_component_parts_on_parent_id_and_child_id", unique: true
    t.index ["parent_id"], name: "index_component_parts_on_parent_id"
    t.index ["step_id"], name: "index_component_parts_on_step_id"
  end

  create_table "components", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "source_url"
    t.datetime "updated_at", null: false
  end

  create_table "food_needs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "household_member_id", null: false
    t.integer "subject_id", null: false
    t.string "subject_type", null: false
    t.integer "tier", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["household_member_id"], name: "index_food_needs_on_household_member_id"
    t.index ["subject_type", "subject_id"], name: "index_food_needs_on_subject"
  end

  create_table "household_members", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ingredient_families", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_ingredient_families_on_name", unique: true
  end

  create_table "ingredients", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "default_unit"
    t.integer "ingredient_family_id"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["ingredient_family_id"], name: "index_ingredients_on_ingredient_family_id"
    t.index ["name"], name: "index_ingredients_on_name", unique: true
  end

  create_table "recipe_imports", force: :cascade do |t|
    t.integer "component_id"
    t.datetime "created_at", null: false
    t.text "error"
    t.text "source_text"
    t.string "source_url"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["component_id"], name: "index_recipe_imports_on_component_id"
  end

  create_table "schedule_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "dish_id", null: false
    t.integer "meal_slot", default: 2, null: false
    t.boolean "restrictions_overridden", default: false, null: false
    t.date "served_on", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["dish_id"], name: "index_schedule_entries_on_dish_id"
  end

  create_table "steps", force: :cascade do |t|
    t.integer "component_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_minutes"
    t.text "instructions"
    t.integer "mode", default: 0, null: false
    t.integer "phase", default: 0, null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["component_id"], name: "index_steps_on_component_id"
  end

  create_table "stock_items", force: :cascade do |t|
    t.date "acquired_on"
    t.datetime "created_at", null: false
    t.date "expires_on"
    t.integer "kind", default: 0, null: false
    t.decimal "quantity", default: "0.0", null: false
    t.integer "stockable_id", null: false
    t.string "stockable_type", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["stockable_type", "stockable_id"], name: "index_stock_items_on_stockable"
  end

  create_table "stock_transactions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "delta", null: false
    t.integer "source", null: false
    t.integer "step_id"
    t.integer "stock_item_id", null: false
    t.datetime "updated_at", null: false
    t.index ["step_id"], name: "index_stock_transactions_on_step_id"
    t.index ["stock_item_id"], name: "index_stock_transactions_on_stock_item_id"
  end

  add_foreign_key "component_ingredients", "components"
  add_foreign_key "component_ingredients", "ingredient_families"
  add_foreign_key "component_ingredients", "ingredients"
  add_foreign_key "component_ingredients", "steps"
  add_foreign_key "component_parts", "components", column: "child_id"
  add_foreign_key "component_parts", "components", column: "parent_id"
  add_foreign_key "component_parts", "steps"
  add_foreign_key "food_needs", "household_members"
  add_foreign_key "ingredients", "ingredient_families"
  add_foreign_key "recipe_imports", "components"
  add_foreign_key "schedule_entries", "components", column: "dish_id"
  add_foreign_key "steps", "components"
  add_foreign_key "stock_transactions", "steps"
  add_foreign_key "stock_transactions", "stock_items"
end
