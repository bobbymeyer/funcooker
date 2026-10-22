# Making an account. In production only the first, unless REGISTRATIONS_OPEN
# is set (see User.registrations_open?).
class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  before_action :require_open_registrations
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.expect(user: %i[ email_address password password_confirmation ]))
    if @user.save
      start_new_session_for @user
      redirect_to after_authentication_url
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def require_open_registrations
      return if User.registrations_open?

      redirect_to new_session_path, alert: "Sign-up is closed.", status: :see_other
    end
end
