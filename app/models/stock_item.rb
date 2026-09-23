# One lot of stock. The kind says what tier it sits in: a raw ingredient, a
# prepped component, or a finished dish in the freezer bank.
#
# Every change to the quantity is a StockTransaction: record! names its
# source, and anything else (a lot entered or corrected by hand) is manual.
class StockItem < ApplicationRecord
  belongs_to :stockable, polymorphic: true
  has_many :stock_transactions, dependent: :destroy
  has_one :receipt_line, dependent: :nullify

  after_save :record_quantity_change, if: :saved_change_to_quantity?

  enum :kind, { raw: 0, prepped: 1, frozen_meal: 2 }, validate: true

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validate :stockable_matches_kind

  scope :on_hand, -> { where.not(quantity: ..0) }
  scope :expiring_by, ->(date) { on_hand.where(expires_on: ..date).order(:expires_on) }

  def record!(delta, source:, step: nil)
    @change = { source:, step: }
    update!(quantity: quantity + delta)
  ensure
    @change = nil
  end

  # For the form: a raw lot names its ingredient, a prepped or frozen lot its
  # component.
  def ingredient_name
    stockable.name if stockable.is_a?(Ingredient)
  end

  def ingredient_name=(name)
    name = name.to_s.squish.downcase
    self.stockable = Ingredient.find_or_initialize_by(name:) if name.present?
  end

  def component_id
    stockable_id if stockable.is_a?(Component)
  end

  def component_id=(id)
    self.stockable = Component.find(id) if id.present?
  end

  private
    def record_quantity_change
      before, after = saved_change_to_quantity
      delta = after - (before || 0)
      stock_transactions.create!(delta:, **(@change || { source: :manual })) unless delta.zero?
    end

    def stockable_matches_kind
      expected = raw? ? "Ingredient" : "Component"
      errors.add(:stockable, "must be a #{expected.downcase} for #{kind.humanize(capitalize: false)} stock") unless stockable_type == expected
      errors.add(:stockable, "must be a dish for frozen meal stock") if frozen_meal? && stockable.is_a?(Component) && !stockable.dish?
    end
end
