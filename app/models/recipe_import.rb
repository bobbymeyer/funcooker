# One recipe coming in from a URL, pasted text, or the name of a dish too
# simple for anyone to publish a recipe for. It lands as a single Component;
# breaking it into sub-components is done by hand afterwards.
class RecipeImport < ApplicationRecord
  class Error < StandardError; end

  belongs_to :component, optional: true

  enum :status, { pending: 0, processing: 1, succeeded: 2, failed: 3 }, validate: true

  normalizes :source_url, :source_text, :simple_dish, with: ->(value) { value.strip.presence }

  validate :one_source
  validates :source_url, format: { with: %r{\Ahttps?://\S+\z}, message: "must be an http or https URL" }, allow_nil: true

  broadcasts_refreshes

  after_create_commit -> { RecipeImportJob.perform_later(self) }

  def process
    processing!
    update!(status: :succeeded, component: build_component(extract))
  rescue Error, Llm::Error => e
    update!(status: :failed, error: e.message)
  rescue => e
    update!(status: :failed, error: "Import failed (#{e.class})")
    raise
  end

  private
    def one_source
      case sources.count(&:present?)
      when 0 then errors.add(:base, "Give a URL, paste a recipe, or name a simple dish")
      when 2.. then errors.add(:base, "Give only one of a URL, a pasted recipe, or a simple dish")
      end
    end

    def sources
      [ source_url, source_text, simple_dish ]
    end

    def extract
      recipe = if source_url
        page = Page.fetch(source_url)
        Extraction.from_json_ld(page.json_ld_recipe) || Extraction.from_text(page.text)
      elsif simple_dish
        Extraction.simplest(simple_dish, servings: [ HouseholdMember.count, 1 ].max)
      else
        Extraction.from_text(source_text)
      end
      raise Error, "No recipe found" if recipe[:ingredients].empty? && recipe[:steps].empty?

      recipe
    end

    def build_component(recipe)
      Component.transaction do
        Component.create!(name: recipe[:name].presence || "untitled recipe", description: recipe[:description], source_url: source_url).tap do |component|
          recipe[:steps].each.with_index(1) do |instructions, position|
            component.steps.create!(position:, instructions:)
          end

          recipe[:ingredients].each do |line|
            component.component_ingredients.create!(
              ingredient: Ingredient.find_or_create_by!(name: line[:ingredient].squish.downcase),
              quantity: line[:amount], unit: line[:unit], note: line[:note]
            )
          end
        end
      end
    end
end
