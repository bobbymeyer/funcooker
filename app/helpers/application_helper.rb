module ApplicationHelper
  def delete_button(path, confirm:, label: "Delete", quiet: false)
    button_to label, path, method: :delete,
      class: quiet ? "link-quiet" : "button button--danger",
      form: { data: { turbo_confirm: confirm } }
  end

  def quantity(value)
    number_with_precision(value, strip_insignificant_zeros: true, precision: 3)
  end

  # How long a lot has left, in words: "expired 2 days ago", "today",
  # "tomorrow", "3 days (Sep 26)".
  def keeps_until(date)
    return "" unless date

    days = (date - Date.current).to_i
    case days
    when ...0 then "expired #{pluralize(-days, "day")} ago"
    when 0 then "today"
    when 1 then "tomorrow"
    else "#{pluralize(days, "day")} (#{l(date, format: "%b %-d")})"
    end
  end

  def ingredient_datalist(id = "ingredient-names")
    tag.datalist(id:) { safe_join(Ingredient.order(:name).pluck(:name).map { |name| tag.option(value: name) }) }
  end
end
