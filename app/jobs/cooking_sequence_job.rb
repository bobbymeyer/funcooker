class CookingSequenceJob < ApplicationJob
  def perform(session)
    session.sequence
  end
end
