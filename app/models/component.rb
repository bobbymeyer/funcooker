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

  validates :name, presence: true
  validates :source_url, format: { with: %r{\Ahttps?://\S+\z} }, allow_blank: true

  scope :dishes, -> { where.not(id: ComponentPart.select(:child_id)) }

  # Dishes the procedural scheduler may pick: none that would violate a
  # restriction for any of the members eating.
  def self.schedulable_for(members)
    dishes.reject { |dish| dish.restricted_for_any?(members) }
  end

  # Where the recipe came from, when that is a web page, safe to link.
  def source_link
    source_url if source_url.to_s.match?(%r{\Ahttps?://\S+\z})
  end

  def dish?
    !parent_parts.exists?
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
