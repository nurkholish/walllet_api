require "latest_stock_price"

LatestStockPrice.configure do |c|
  c.provider = ENV.fetch("LSP_PROVIDER", "yahoo").to_sym
  c.api_key  = ENV.fetch("RAPIDAPI_KEY", nil)
  c.host     = ENV.fetch("RAPIDAPI_HOST", "latest-stock-price.p.rapidapi.com")
  c.base_url = ENV.fetch("RAPIDAPI_BASE_URL", "https://latest-stock-price.p.rapidapi.com")
  c.stub     = ENV.fetch("LSP_STUB_MODE", "true") == "true"
  c.timeout  = ENV.fetch("LSP_TIMEOUT", 10).to_i
end