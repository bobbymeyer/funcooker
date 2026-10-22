# An account: someone who may sign in. The household's people are
# HouseholdMembers, and need no account to be cooked for.
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 10 }, allow_nil: true

  # Whether a stranger may make an account. Always, unless this environment
  # closes sign-up after the first (production does): then only until there
  # is one.
  def self.registrations_open?
    Rails.configuration.x.registrations_close_after_first != true || !exists?
  end
end
