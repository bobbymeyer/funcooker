module RecipeImportsHelper
  def sophistication_label(level)
    { "divorced_dad" => "divorced dad", "home_cook" => "home cook", "michelin_chef" => "Michelin chef" }.fetch(level)
  end

  # Where an import came from, in a few words.
  def import_source(import)
    if import.source_url then import.source_url
    elsif import.dish_name then "#{import.dish_name}, by a #{sophistication_label(import.sophistication)}"
    elsif import.photos.attached? then [ pluralize(import.photos.size, "photo"), import.source_note ].compact.join(" of ")
    else [ "pasted text", import.source_note ].compact.join(" from ")
    end
  end
end
