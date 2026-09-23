# Breaks a recipe into the components it is made of, reusing existing
# components where one is the same or very close, and rewrites the recipe to
# use them. The recipe's ingredients and steps as they were are kept in
# original, since the rewrite replaces them.
class Decomposition < ApplicationRecord
  class Error < StandardError; end

  belongs_to :component

  enum :status, { pending: 0, processing: 1, succeeded: 2, failed: 3 }, validate: true

  validate :component_not_yet_decomposed, on: :create

  broadcasts_refreshes

  after_create_commit -> { DecompositionJob.perform_later(self) }

  def process
    processing!
    lines = component.component_ingredients.includes(:ingredient, :ingredient_family).order(:id).to_a
    raise Error, "#{component.name} has no ingredients to break out" if lines.empty?

    candidates = Component.where.not(id: [ component.id, *ancestor_ids ]).includes(component_ingredients: %i[ ingredient ingredient_family ]).order(:name).to_a
    plan = Plan.new(component, lines:, candidates:).call
    raise Error, "Nothing to break out: the model found no components in #{component.name}" if plan[:components].empty?

    transaction do
      update!(original: snapshot(lines))
      Rewrite.new(component, lines:, candidates:, plan:).apply
      succeeded!
    end
  rescue Error, Llm::Error => e
    update!(status: :failed, error: e.message)
  rescue => e
    update!(status: :failed, error: "Decomposition failed (#{e.class})")
    raise
  end

  private
    def component_not_yet_decomposed
      errors.add(:component, "is already made of other components") if component&.child_parts&.exists?
    end

    def ancestor_ids
      ids, frontier = [], [ component.id ]
      while frontier.any?
        frontier = ComponentPart.where(child_id: frontier).pluck(:parent_id) - ids
        ids.concat(frontier)
      end
      ids
    end

    def snapshot(lines)
      {
        "ingredients" => lines.map { |line| { "name" => (line.ingredient || line.ingredient_family).name, "quantity" => line.quantity&.to_s, "unit" => line.unit, "note" => line.note } },
        "steps" => component.steps.map { |step| { "instructions" => step.instructions, "phase" => step.phase, "mode" => step.mode } }
      }
    end
end
