require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module WalletApi
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true
    config.autoload_lib(ignore: %w[assets tasks]) rescue nil
    config.eager_load_paths << Rails.root.join("lib")
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc
    config.generators.system_tests = nil
  end
end