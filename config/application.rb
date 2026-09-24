require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Funcooker
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Where the app is reached, for links in calendar events it writes itself.
    config.x.app_url = ENV.fetch("APP_URL", "http://localhost:3000")

    # The OpenAI-compatible endpoint recipe import extracts with. LLM_MODEL is
    # an id from its /v1/models.
    config.x.llm.base_url = ENV.fetch("LLM_BASE_URL", "https://chat.bobbymeyer.com/v1")
    config.x.llm.model = ENV["LLM_MODEL"]
    # For requests with an image, when LLM_MODEL cannot read one.
    config.x.llm.vision_model = ENV["LLM_VISION_MODEL"]
  end
end
