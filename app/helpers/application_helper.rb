module ApplicationHelper
  def delete_button(path, confirm:, label: "Delete", quiet: false)
    button_to label, path, method: :delete,
      class: quiet ? "link-quiet" : "button button--danger",
      form: { data: { turbo_confirm: confirm } }
  end

  def quantity(value)
    number_with_precision(value, strip_insignificant_zeros: true, precision: 3)
  end

  # Minutes as "1 h 20 min".
  def duration_in_words(minutes)
    hours, minutes = minutes.to_i.divmod(60)
    [ ("#{hours} h" if hours.positive?), ("#{minutes} min" if minutes.positive? || hours.zero?) ].compact.join(" ")
  end

  # A lot's quantity with its unit, in the plural where it is not one: "4
  # servings", "1 lb".
  def amount_of(lot)
    [ quantity(lot.quantity), (lot.unit.pluralize(lot.quantity == 1 ? 1 : 2) if lot.unit.present?) ].compact.join(" ")
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
