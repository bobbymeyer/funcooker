# Points at either a locked Ingredient (no swap) or an IngredientFamily (any
# member substitutable), never both.
class ComponentIngredient < ApplicationRecord
  belongs_to :component
  belongs_to :ingredient, optional: true
  belongs_to :ingredient_family, optional: true
  belongs_to :step, optional: true

  validate :exactly_one_of_ingredient_or_family

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
