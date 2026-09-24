module FreezersHelper
  # When a thaw should come out of the freezer, in words.
  def thaw_by(thaw)
    if thaw.by == Date.current
      thaw.entry.served_on == Date.current ? "now" : "tonight"
    else
      "#{thaw.by.strftime("%A")} evening"
    end
  end

  # Whole meals a frozen lot makes for this many adult portions. A lot not
  # counted in servings is taken as one.
  def meals_in(lot, portions)
    return 1 unless Cooking::Meal.serving_unit?(lot.unit)
    return 0 unless portions.positive?

    (lot.quantity / portions).floor
  end
end
