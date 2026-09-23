# A Dish is a Component with nothing above it: it is never the child of another
# Component. There is no separate table or subclass.
class Component < ApplicationRecord
  has_many :steps, -> { order(:position) }, dependent: :destroy
  has_many :component_ingredients, dependent: :destroy
  has_many :child_parts, class_name: "ComponentPart", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :parent_parts, class_name: "ComponentPart", foreign_key: :child_id, dependent: :restrict_with_error, inverse_of: :child
  has_many :children, through: :child_parts, source: :child
  has_many :parents, through: :parent_parts, source: :parent
  has_many :stock_items, as: :stockable, dependent: :restrict_with_error
  has_many :food_needs, as: :subject, dependent: :destroy
  has_many :schedule_entries, foreign_key: :dish_id, dependent: :restrict_with_error, inverse_of: :dish
  has_many :decompositions, dependent: :destroy
  has_many :recipe_imports, dependent: :nullify
  has_many :prep_batches, dependent: :destroy

  validates :name, presence: true
  validates :shelf_life_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :source_url, format: { with: %r{\Ahttps?://\S+\z} }, allow_blank: true

  scope :dishes, -> { where.not(id: ComponentPart.select(:child_id)) }
  scope :parts, -> { where(id: ComponentPart.select(:child_id)) }

  broadcasts_refreshes

  # A shelf life set by hand is not the model's any more, so its note goes.
  before_update -> { self.shelf_life_note = nil }, if: -> { shelf_life_days_changed? && !shelf_life_note_changed? }

  def estimate_shelf_life_later(overwrite: false)
    ShelfLifeJob.perform_later(self, overwrite:)
  end

  # Dishes the procedural scheduler may pick: none that would violate a
  # restriction for any of the members eating.
  def self.schedulable_for(members)
    dishes.reject { |dish| dish.restricted_for_any?(members) }
  end

  # Where the recipe came from, when that is a web page, safe to link.
  def source_link
    source_url if source_url.to_s.match?(%r{\Ahttps?://\S+\z})
  end

  # A recipe not yet broken into components, with ingredients to break out,
  # and no borderline judgement waiting on a decision.
  def decomposable?
    !child_parts.exists? && component_ingredients.exists? && !decompositions.awaiting.exists?
  end

  def dish?
    !parent_parts.exists?
  end

  # Every component this one is part of, at any depth.
  def ancestor_ids
    ids, frontier = [], [ id ]
    while frontier.any?
      frontier = ComponentPart.where(child_id: frontier).pluck(:parent_id) - ids
      ids.concat(frontier)
    end
    ids
  end

  # What can go inside this component without making a cycle.
  def part_candidates
    Component.where.not(id: [ id, *ancestor_ids ]).order(:name)
  end

  # This component and every component nested inside it, at any depth.
  def self_and_descendants
    [ self ] + children.flat_map(&:self_and_descendants)
  end

  def restricted_for?(member)
    RestrictionCheck.new(member).violated_by?(self)
  end

  def restricted_for_any?(members)
    members.any? { |member| restricted_for?(member) }
  end
end
