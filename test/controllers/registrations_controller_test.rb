require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  teardown { Rails.configuration.x.registrations_close_after_first = false }

  test "make an account and be signed in" do
    get new_registration_path
    assert_response :success

    post registration_path, params: { user: { email_address: "Second@Example.com", password: "another long one", password_confirmation: "another long one" } }

    assert_redirected_to root_path
    assert cookies[:session_id]
    assert User.exists?(email_address: "second@example.com")
  end

  test "a short password is refused" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { email_address: "short@example.com", password: "short", password_confirmation: "short" } }
    end
    assert_response :unprocessable_entity
  end

  test "where sign-up closes after the first, it is open until there is an account" do
    Rails.configuration.x.registrations_close_after_first = true
    User.delete_all

    get new_session_path
    assert_select "a", "Make an account"

    post registration_path, params: { user: { email_address: "first@example.com", password: "the first one", password_confirmation: "the first one" } }
    assert_redirected_to root_path
    sign_out

    get new_session_path
    assert_select "a", text: "Make an account", count: 0

    get new_registration_path
    assert_redirected_to new_session_path
    assert_equal "Sign-up is closed.", flash[:alert]

    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { email_address: "third@example.com", password: "the third one", password_confirmation: "the third one" } }
    end
    assert_redirected_to new_session_path
  end
end
