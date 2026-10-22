require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_out
    @user = User.take
  end

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "a long password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "signed out, every page asks for a sign-in, JSON included" do
    [ root_path, schedule_entries_path, shopping_list_path(format: :json), freezer_path(format: :json), calendar_path ].each do |path|
      get path
      assert_redirected_to new_session_path, path
    end

    assert_no_difference -> { Ingredient.count } do
      post ingredients_path, params: { ingredient: { name: "shallot" } }
    end
    assert_redirected_to new_session_path
  end

  test "the health check answers without a session" do
    get rails_health_check_path
    assert_response :success
  end
end
