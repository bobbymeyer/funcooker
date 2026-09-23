# One recipe coming in from a URL, pasted text, or the name of a dish for the
# model to write — often one too simple for anyone to publish a recipe for. It lands as a single Component;
# breaking it into sub-components is done by hand afterwards.
#
# Amounts are always stored for one adult. Scaling up to whoever is eating
# happens later, from these.
class RecipeImport < ApplicationRecord
  class Error < StandardError; end

  belongs_to :component, optional: true

  enum :status, { pending: 0, processing: 1, succeeded: 2, failed: 3 }, validate: true
  enum :sophistication, { divorced_dad: 0, home_cook: 1, michelin_chef: 2 }, validate: true

  normalizes :source_url, :source_text, :dish_name, with: ->(value) { value.strip.presence }

  validate :one_source
  validates :source_url, format: { with: %r{\Ahttps?://\S+\z}, message: "must be an http or https URL" }, allow_nil: true

  broadcasts_refreshes

  after_create_commit -> { RecipeImportJob.perform_later(self) }

  def process
    processing!
    update!(status: :succeeded, component: build_component(extract))
    component.estimate_shelf_life_later
  rescue Error, Llm::Error => e
    update!(status: :failed, error: e.message)
  rescue => e
    update!(status: :failed, error: "Import failed (#{e.class})")
    raise
  end

  private
    def one_source
      case sources.count(&:present?)
      when 0 then errors.add(:base, "Give a URL, paste a recipe, or name a dish")
      when 2.. then errors.add(:base, "Give only one of a URL, a pasted recipe, or a dish")
      end
    end

    def sources
      [ source_url, source_text, dish_name ]
    end

    def extract
      recipe = if source_url
        page = Page.fetch(source_url)
        Extraction.from_json_ld(page.json_ld_recipe) || Extraction.from_text(page.text)
      elsif dish_name
        Extraction.generate(dish_name, sophistication:)
      else
        Extraction.from_text(source_text)
      end
      raise Error, "No recipe found" if recipe[:ingredients].empty? && recipe[:steps].empty?
      raise Error, "The model gave #{recipe[:servings].inspect} servings" unless recipe[:servings].to_f.positive?

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
              quantity: per_adult(line[:amount], recipe[:servings]), unit: line[:unit], note: line[:note]
            )
          end
        end
      end
    end

    def per_adult(amount, servings)
      (amount.to_d / servings.to_d).round(4) if amount
    end
end
