# Breaks a recipe into the components it is made of, reusing existing
# components where one is the same or very close, and rewrites the recipe to
# use them. The recipe's ingredients and steps as they were are kept in
# original, since the rewrite replaces them.
#
# The model judges first. A recipe it finds atomic is declined with its
# reason and left as it is. A borderline one waits, with the plan and its
# caveats, until someone decides: confirm applies the plan, dismiss drops it.
class Decomposition < ApplicationRecord
  class Error < StandardError; end

  belongs_to :component

  enum :status, { pending: 0, processing: 1, succeeded: 2, failed: 3, declined: 4, awaiting: 5, dismissed: 6 }, validate: true

  validate :component_not_yet_decomposed, on: :create

  broadcasts_refreshes

  after_create_commit -> { DecompositionJob.perform_later(self) }

  def process
    processing!
    lines = component.component_ingredients.includes(:ingredient, :ingredient_family).order(:id).to_a
    raise Error, "#{component.name} has no ingredients to break out" if lines.empty?

    candidates = candidates_for_reuse
    plan = Plan.new(component, lines:, candidates:).call
    judge = { verdict: plan[:verdict], reason: plan[:reason].to_s.squish.presence, caveats: Array(plan[:caveats]).map(&:squish).compact_blank }

    if plan[:verdict] == "atomic" || plan[:components].blank?
      update!(status: :declined, **judge.merge(reason: judge[:reason] || "The model found nothing in #{component.name} worth making on its own."))
    elsif plan[:verdict] == "borderline"
      update!(status: :awaiting, plan:, line_ids: lines.map(&:id), **judge)
    else
      update!(**judge)
      apply(plan, lines, candidates)
    end
  rescue Error, Llm::Error => e
    update!(status: :failed, error: e.message)
  rescue => e
    update!(status: :failed, error: "Decomposition failed (#{e.class})")
    raise
  end

  # Decompose anyway: the waiting plan, as long as the recipe is as it was.
  def confirm!
    raise Error, "Only a decomposition waiting on a decision can be confirmed" unless awaiting?

    lines = component.component_ingredients.includes(:ingredient, :ingredient_family).where(id: line_ids).order(:id).to_a
    unless lines.map(&:id) == line_ids && component.component_ingredients.count == line_ids.size && !component.child_parts.exists?
      raise Error, "#{component.name} has changed since it was judged. Decompose it again."
    end

    apply(plan.deep_symbolize_keys, lines, candidates_for_reuse)
  end

  def dismiss!
    raise Error, "Only a decomposition waiting on a decision can be dismissed" unless awaiting?

    dismissed!
  end

  private
    def component_not_yet_decomposed
      errors.add(:component, "is already made of other components") if component&.child_parts&.exists?
    end

    def candidates_for_reuse
      component.part_candidates.includes(component_ingredients: %i[ ingredient ingredient_family ]).to_a
    end

    def apply(plan, lines, candidates)
      created = []
      transaction do
        update!(original: snapshot(lines))
        created = Rewrite.new(component, lines:, candidates:, plan:).apply
        succeeded!
      end
      created.each(&:estimate_shelf_life_later)
    end

    def snapshot(lines)
      {
        "ingredients" => lines.map { |line| { "name" => (line.ingredient || line.ingredient_family).name, "quantity" => line.quantity&.to_s, "unit" => line.unit, "note" => line.note } },
        "steps" => component.steps.map { |step| { "instructions" => step.instructions, "phase" => step.phase, "mode" => step.mode } }
      }
    end
end
