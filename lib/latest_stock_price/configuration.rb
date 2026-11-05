module LatestStockPrice
  class Configuration
    attr_accessor :api_key, :host, :base_url, :stub, :timeout, :provider

    def initialize
      @provider = (ENV["LSP_PROVIDER"] || "yahoo").to_sym
      @api_key  = nil
      @host     = "latest-stock-price.p.rapidapi.com"
      @base_url = "https://latest-stock-price.p.rapidapi.com"
      @stub     = ENV.fetch("LSP_STUB_MODE", "true") == "true"
      @timeout  = ENV.fetch("LSP_TIMEOUT", 10).to_i
    end

    def validate!
      return if stub
      return unless provider == :rapidapi

      raise ConfigurationError, "api_key is required for rapidapi" if api_key.to_s.empty?
      raise ConfigurationError, "host is required for rapidapi"    if host.to_s.empty?
    end
  end
end