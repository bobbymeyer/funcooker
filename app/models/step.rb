class Step < ApplicationRecord
  belongs_to :component
  has_many :component_ingredients, dependent: :nullify
  has_many :component_parts, dependent: :nullify
  has_many :stock_transactions, dependent: :nullify
  has_many :cooking_tasks, dependent: :destroy

  enum :phase, { prep: 0, plate: 1 }, validate: true
  enum :mode, { active: 0, passive: 1 }, validate: true

  validates :position, presence: true, numericality: { only_integer: true }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
