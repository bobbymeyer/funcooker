require "test_helper"

class HouseholdMembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @kid = HouseholdMember.create!(name: "kid")
    @beef = Ingredient.create!(name: "ground beef")
  end

  test "index" do
    @kid.food_needs.create!(subject: @beef, tier: :restriction)

    get household_members_path
    assert_select "td", "ground beef"
  end

  test "add, rename and remove someone" do
    get new_household_member_path
    assert_response :success

    post household_members_path, params: { household_member: { name: "Bobby" } }
    bobby = HouseholdMember.find_by!(name: "Bobby")
    assert_redirected_to edit_household_member_path(bobby)

    patch household_member_path(bobby), params: { household_member: { name: "Robert" } }
    assert_equal "Robert", bobby.reload.name

    delete household_member_path(bobby)
    assert_not HouseholdMember.exists?(bobby.id)
  end

  test "add, edit and remove a food need" do
    get edit_household_member_path(@kid)
    assert_select "optgroup[label=Ingredients] option", "ground beef"

    post household_member_food_needs_path(@kid), params: { food_need: { subject_key: "Ingredient:#{@beef.id}", tier: "preference", sentiment: "dislikes" } }
    need = @kid.food_needs.sole
    assert need.dislikes?

    get edit_food_need_path(need)
    assert_response :success
    patch food_need_path(need), params: { food_need: { tier: "restriction" } }
    assert need.reload.restriction?

    delete food_need_path(need)
    assert_empty @kid.food_needs.reload
  end

  test "a food need without a food is refused" do
    post household_member_food_needs_path(@kid), params: { food_need: { subject_key: "", tier: "restriction", sentiment: "likes" } }
    assert_response :unprocessable_entity
  end
end
