Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.log_level = :info
  config.log_to_stdout = ENV["RAILS_LOG_TO_STDOUT"].present?
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.force_ssl = false
  config.active_support.report_deprecations = false
end