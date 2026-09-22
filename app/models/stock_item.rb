# One lot of stock. The kind says what tier it sits in: a raw ingredient, a
# prepped component, or a finished dish in the freezer bank.
class StockItem < ApplicationRecord
  belongs_to :stockable, polymorphic: true
  has_many :stock_transactions, dependent: :destroy

  enum :kind, { raw: 0, prepped: 1, frozen_meal: 2 }, validate: true

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validate :stockable_matches_kind

  scope :on_hand, -> { where.not(quantity: ..0) }
  scope :expiring_by, ->(date) { on_hand.where(expires_on: ..date).order(:expires_on) }

  def record!(delta, source:, step: nil)
    transaction do
      stock_transactions.create!(delta: delta, source: source, step: step)
      update!(quantity: quantity + delta)
    end
  end

  private
    def stockable_matches_kind
      expected = raw? ? "Ingredient" : "Component"
      errors.add(:stockable, "must be a #{expected.downcase} for #{kind.humanize(capitalize: false)} stock") unless stockable_type == expected
      errors.add(:stockable, "must be a dish for frozen meal stock") if frozen_meal? && stockable && !stockable.dish?
    end
end
