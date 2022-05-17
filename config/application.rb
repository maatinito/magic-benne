# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DemarchesSefi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Configuration for the application, engines, and railties goes here.
    #
    config.time_zone = 'Pacific/Tahiti'

    config.active_job.queue_adapter = :delayed_job

    I18n.available_locales = %i[en fr]
    I18n.default_locale = :fr
  end
end
