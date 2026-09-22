class ComponentPart < ApplicationRecord
  belongs_to :parent, class_name: "Component", inverse_of: :child_parts
  belongs_to :child, class_name: "Component", inverse_of: :parent_parts
  belongs_to :step, optional: true

  validates :child_id, uniqueness: { scope: :parent_id }
  validate :no_cycles

  private
    def no_cycles
      return unless parent && child

      if parent == child || child.self_and_descendants.include?(parent)
        errors.add(:child, "would contain its own parent")
      end
    end
end
