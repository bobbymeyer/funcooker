# One lot of stock. The kind says what tier it sits in: a raw ingredient, or
# a component, prepped in the fridge or frozen. Frozen is the freezer bank: the
# same components, keeping far longer, and the dishes among them are what the
# easy button reaches for.
#
# Every change to the quantity is a StockTransaction: record! names its
# source, and anything else (a lot entered or corrected by hand) is manual.
class StockItem < ApplicationRecord
  belongs_to :stockable, polymorphic: true
  has_many :stock_transactions, dependent: :destroy
  has_one :receipt_line, dependent: :nullify
  has_one :prep_batch, dependent: :nullify
  has_one :frozen_prep_batch, class_name: "PrepBatch", foreign_key: :frozen_stock_item_id, dependent: :nullify, inverse_of: :frozen_stock_item

  after_save :record_quantity_change, if: :saved_change_to_quantity?

  enum :kind, { raw: 0, prepped: 1, freezer: 2 }, validate: true

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validate :stockable_matches_kind

  scope :on_hand, -> { where.not(quantity: ..0) }
  scope :expiring_by, ->(date) { on_hand.where(expires_on: ..date).order(:expires_on) }
  scope :first_out, -> { order(Arel.sql("expires_on IS NULL"), :expires_on, :id) }
  # Prepped or frozen: a component ready to use, whichever box it is in.
  scope :stocked, -> { where(kind: %i[ prepped freezer ]) }

  class CannotMove < StandardError; end

  # Frozen dishes: what the easy button can swap in.
  def self.easy_meals
    on_hand.freezer.where(stockable_type: "Component", stockable_id: Component.dishes.select(:id)).includes(:stockable)
  end

  # Whether this lot makes a meal for these people: none restricted from it,
  # and servings enough for their portions when it is counted in servings.
  def feeds?(members)
    freezer? && quantity.positive? && stockable.is_a?(Component) && stockable.dish? && !stockable.restricted_for_any?(members) &&
      (!Cooking::Meal.serving_unit?(unit) || quantity >= members.sum(&:portion))
  end

  def record!(delta, source:, step: nil)
    @change = { source:, step: }
    update!(quantity: quantity + delta)
  ensure
    @change = nil
  end

  # Moves servings of a prepped lot into a new frozen lot, which keeps as long
  # as the component keeps frozen, counted from today.
  def freeze!(servings = quantity)
    component = stockable
    raise CannotMove, "Only prepped stock goes in the freezer" unless prepped?
    raise CannotMove, "#{component.name} does not freeze well#{": #{component.freezer_life_note}" if component.freezer_life_note}" unless component.freezable?

    move!(servings, kind: :freezer, keeps: component.freezer_life_days)
  end

  # Moves servings of a frozen lot back to the fridge, where they keep as long
  # as the component keeps prepped, counted from today.
  def thaw!(servings = quantity)
    raise CannotMove, "Only frozen stock thaws" unless freezer?

    move!(servings, kind: :prepped, keeps: stockable.shelf_life_days)
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
    def move!(servings, kind:, keeps:)
      servings = servings.to_d
      raise CannotMove, "Pick between 0 and #{quantity.round(3).to_s("F").sub(/\.0\z/, "")}#{" #{unit.pluralize}" if unit.present?}" unless servings.positive? && servings <= quantity

      transaction do
        record!(-servings, source: :freezer)
        StockItem.create!(stockable:, kind:, unit:, acquired_on: Date.current, expires_on: (Date.current + keeps if keeps)).tap do |lot|
          lot.record!(servings, source: :freezer)
        end
      end
    end

    def record_quantity_change
      before, after = saved_change_to_quantity
      delta = after - (before || 0)
      stock_transactions.create!(delta:, **(@change || { source: :manual })) unless delta.zero?
    end

    def stockable_matches_kind
      expected = raw? ? "Ingredient" : "Component"
      errors.add(:stockable, "must be a #{expected.downcase} for #{kind.humanize(capitalize: false)} stock") unless stockable_type == expected
    end
end
