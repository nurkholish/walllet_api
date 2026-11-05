module LatestStockPrice
  class Error              < StandardError; end
  class ConfigurationError < Error; end
  class HTTPError          < Error; end
  class RateLimitError     < HTTPError; end
  class NotFoundError      < HTTPError; end
end