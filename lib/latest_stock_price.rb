require_relative "latest_stock_price/version"
require_relative "latest_stock_price/errors"
require_relative "latest_stock_price/configuration"
require_relative "latest_stock_price/client"

module LatestStockPrice
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
      @client = nil
    end

    def client
      @client ||= Client.new(configuration)
    end

    def reset_client!
      @client = nil
    end

    def price(symbol)
      client.price(symbol)
    end

    def prices(symbols)
      client.prices(symbols)
    end

    def price_all
      client.price_all
    end
  end
end