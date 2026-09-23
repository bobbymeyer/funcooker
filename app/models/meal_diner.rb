class MealDiner < ApplicationRecord
  belongs_to :schedule_entry
  belongs_to :household_member

  validates :household_member_id, uniqueness: { scope: :schedule_entry_id }
end
