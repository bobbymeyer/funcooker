module RecipeImportsHelper
  def sophistication_label(level)
    { "divorced_dad" => "divorced dad", "home_cook" => "home cook", "michelin_chef" => "Michelin chef" }.fetch(level)
  end
end
