# Points at either a locked Ingredient (no swap) or an IngredientFamily (any
# member substitutable), never both.
class ComponentIngredient < ApplicationRecord
  belongs_to :component
  belongs_to :ingredient, optional: true
  belongs_to :ingredient_family, optional: true
  belongs_to :step, optional: true

  validate :exactly_one_of_ingredient_or_family

  # For the form: the ingredient by name, added to the library if it is new.
  def ingredient_name
    ingredient&.name
  end

  def ingredient_name=(name)
    name = name.to_s.squish.downcase
    self.ingredient = name.presence && Ingredient.find_or_initialize_by(name:)
  end

  def substitutable?
    ingredient_family.present?
  end

  def candidates
    substitutable? ? ingredient_family.ingredients : [ ingredient ]
  end

  private
    def exactly_one_of_ingredient_or_family
      if ingredient.present? == ingredient_family.present?
        errors.add(:base, "must reference exactly one of an ingredient or an ingredient family")
      end
    end
end
