module ApplicationHelper
  def delete_button(path, confirm:, label: "Delete", quiet: false)
    button_to label, path, method: :delete,
      class: quiet ? "link-quiet" : "button button--danger",
      form: { data: { turbo_confirm: confirm } }
  end

  def quantity(value)
    number_with_precision(value, strip_insignificant_zeros: true, precision: 3)
  end

  def ingredient_datalist(id = "ingredient-names")
    tag.datalist(id:) { safe_join(Ingredient.order(:name).pluck(:name).map { |name| tag.option(value: name) }) }
  end
end
