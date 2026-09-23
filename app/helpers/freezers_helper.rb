module FreezersHelper
  # Whole meals a frozen lot makes for this many adult portions. A lot not
  # counted in servings is taken as one.
  def meals_in(lot, portions)
    return 1 unless Cooking::Meal.serving_unit?(lot.unit)
    return 0 unless portions.positive?

    (lot.quantity / portions).floor
  end
end
