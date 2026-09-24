class ApplicationJob < ActiveJob::Base
  # Today is the household's today.
  around_perform { |_, job| Household.in_zone(&job) }

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
