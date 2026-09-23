# Applies a Decomposition::Plan: the recipe's own ingredient lines and steps
# are replaced by parts (new or reused components, each one serving for one
# adult unless the plan says otherwise), the lines the dish uses directly, and
# its rewritten steps. A reused component stands in for the lines it replaces.
# A line the plan leaves unused stays on the dish, so no ingredient is lost.
class Decomposition::Rewrite
  def initialize(component, lines:, candidates:, plan:)
    @component, @candidates, @plan = component, candidates, plan
    @lines = lines.each_with_index.to_h do |line, index|
      [ "i#{index + 1}", line.attributes.slice("ingredient_id", "ingredient_family_id", "quantity", "unit", "note").symbolize_keys ]
    end
    @used = Set.new
  end

  def apply
    @component.component_ingredients.destroy_all
    @component.steps.destroy_all

    parts = @plan[:components].each_with_object({}) { |planned, parts| add_part(planned, parts) }
    direct = Array(@plan[:ingredients]).to_h { |ref| [ ref[:line], add_line(@component, ref) ] }
    (@lines.keys - @used.to_a).each { |id| direct[id] = add_line(@component, { line: id }) }

    Array(@plan[:steps]).each.with_index(1) do |planned, position|
      step = @component.steps.create!(position:, **step_attributes(planned))
      Array(planned[:uses]).each do |use|
        consumed = parts[use.to_s.squish.downcase] || direct[use.to_s.strip]
        consumed.update!(step:) if consumed && consumed.step_id.nil?
      end
    end
  end

  private
    def add_part(planned, parts)
      child, servings = resolve(planned)
      return unless child

      part = @component.child_parts.find_by(child:)
      if part
        part.update!(quantity: part.quantity + servings)
      else
        part = @component.child_parts.create!(child:, quantity: servings, unit: "serving")
      end
      [ planned[:name], child.name ].compact.each { |name| parts[name.squish.downcase] = part }
    end

    def resolve(planned)
      if planned[:existing].present?
        existing = @candidates.find { |candidate| candidate.name == planned[:existing] } or
          raise Decomposition::Error, "The model reused a component that is not in the library: #{planned[:existing]}"
        Array(planned[:ingredients]).each { |ref| @used << ref[:line] } # the lines it stands in for
        [ existing, planned[:servings].to_f.positive? ? planned[:servings].to_d : 1 ]
      elsif Array(planned[:ingredients]).any? || Array(planned[:steps]).any?
        [ build_component(planned), 1 ]
      end
    end

    def build_component(planned)
      Component.create!(name: planned[:name].to_s.squish.presence || "part of #{@component.name}").tap do |child|
        planned[:ingredients].each { |ref| add_line(child, ref) }
        Array(planned[:steps]).each.with_index(1) { |step, position| child.steps.create!(position:, **step_attributes(step)) }
      end
    end

    def add_line(owner, ref)
      original = @lines.fetch(ref[:line]) { raise Decomposition::Error, "The model referred to an ingredient line that does not exist: #{ref[:line]}" }
      @used << ref[:line]

      owner.component_ingredients.create!(
        ingredient_id: original[:ingredient_id], ingredient_family_id: original[:ingredient_family_id],
        quantity: ref[:amount].nil? ? original[:quantity] : ref[:amount],
        unit: ref[:unit].presence || original[:unit],
        note: ref[:note].presence || original[:note]
      )
    end

    def step_attributes(planned)
      planned.slice(:instructions, :phase, :mode, :duration_minutes).merge(duration_minutes: planned[:duration_minutes].to_i.positive? ? planned[:duration_minutes] : nil)
    end
end
