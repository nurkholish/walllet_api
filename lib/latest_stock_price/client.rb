require "faraday"
require "json"

module LatestStockPrice
  class Client
    STUB_PRICES = {
      "AAPL" => { "symbol" => "AAPL", "price" => 189.43, "currency" => "USD",
                  "name" => "Apple Inc.", "exchange" => "NMS", "as_of" => nil },
      "MSFT" => { "symbol" => "MSFT", "price" => 421.90, "currency" => "USD",
                  "name" => "Microsoft Corporation", "exchange" => "NMS", "as_of" => nil },
      "GOOG" => { "symbol" => "GOOG", "price" => 178.35, "currency" => "USD",
                  "name" => "Alphabet Inc.", "exchange" => "NMS", "as_of" => nil },
      "TSLA" => { "symbol" => "TSLA", "price" => 248.10, "currency" => "USD",
                  "name" => "Tesla, Inc.", "exchange" => "NMS", "as_of" => nil }
    }.freeze

    YAHOO_BASE = "https://query1.finance.yahoo.com".freeze

    YAHOO_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " \
               "AppleWebKit/537.36 (KHTML, like Gecko) " \
               "Chrome/125.0 Safari/537.36".freeze

    def initialize(config = LatestStockPrice.configuration)
      @config = config
      @config.validate!
    end

    def price(symbol)
      sym = normalize_symbol!(symbol)
      return stub_price(sym) if @config.stub

      case @config.provider
      when :yahoo    then yahoo_quote(sym)
      when :rapidapi then perform_rapidapi_get("/price", { stock: sym })
      else raise ConfigurationError, "unknown provider #{@config.provider}"
      end
    end

    def prices(symbols)
      syms = Array(symbols).map { |s| normalize_symbol!(s) }.reject(&:empty?)
      return syms.map { |s| stub_price(s) } if @config.stub

      case @config.provider
      when :yahoo
        syms.map { |s| yahoo_quote(s) }
      when :rapidapi
        perform_rapidapi_get("/prices", { stocks: syms.join(",") })
      else
        raise ConfigurationError, "unknown provider #{@config.provider}"
      end
    end

    def price_all
      return STUB_PRICES.values if @config.stub

      case @config.provider
      when :yahoo
        %w[AAPL MSFT GOOG TSLA AMZN NVDA META].map { |s| yahoo_quote(s) }
      when :rapidapi
        perform_rapidapi_get("/price_all", {})
      else
        raise ConfigurationError, "unknown provider #{@config.provider}"
      end
    end

    private

    def normalize_symbol!(sym)
      s = sym.to_s.strip.upcase
      raise NotFoundError, "symbol required" if s.empty?
      unless s.match?(/\A[A-Z0-9\.\-]{1,15}\z/)
        raise NotFoundError, "invalid symbol #{sym.inspect}"
      end
      s
    end

    def stub_price(sym)
      STUB_PRICES.fetch(sym) { raise NotFoundError, "symbol #{sym} not found" }
    end

    def yahoo_connection
      @yahoo_connection ||= Faraday.new(url: YAHOO_BASE, request: { timeout: @config.timeout }) do |f|
        f.response :json, content_type: /\bjson$/
        f.headers["User-Agent"] = YAHOO_UA
        f.headers["Accept"]     = "application/json"
        f.headers["Accept-Language"] = "en-US,en;q=0.9"
        f.adapter Faraday.default_adapter
      end
    end

    def yahoo_quote(sym)
      resp = yahoo_connection.get("/v8/finance/chart/#{sym}", { range: "1d", interval: "1d" })

      case resp.status
      when 200
        parse_yahoo_payload!(resp.body, requested: sym)
      when 404
        raise NotFoundError, "symbol #{sym} not found on Yahoo"
      when 422
        raise NotFoundError, "symbol #{sym} invalid on Yahoo"
      when 429
        raise RateLimitError, "Yahoo rate limit for #{sym}"
      when 400..499
        # Yahoo kadang balas 4xx untuk symbol tidak ada
        raise NotFoundError, "Yahoo #{resp.status} for #{sym}"
      else
        raise HTTPError, "Yahoo HTTP #{resp.status}: #{resp.body.to_s[0, 200]}"
      end
    rescue Faraday::ParsingError
      # Yahoo kadang balas HTML consent page untuk symbol invalid
      raise NotFoundError, "symbol #{sym} not found (non-JSON response)"
    rescue Faraday::Error => e
      raise HTTPError, "Yahoo connection error: #{e.message}"
    end

    def parse_yahoo_payload!(body, requested:)
      chart = body.is_a?(Hash) ? body["chart"] : nil
      raise NotFoundError, "symbol #{requested} not found (empty response)" unless chart.is_a?(Hash)

      if chart["error"]
        msg = chart["error"]["description"] || chart["error"].to_s
        # Error dari Yahoo untuk symbol invalid biasanya di sini
        raise NotFoundError, "Yahoo error for #{requested}: #{msg}"
      end

      result = Array(chart["result"]).first
      raise NotFoundError, "symbol #{requested} not found (no result)" unless result.is_a?(Hash)

      meta  = result["meta"] || {}
      price = meta["regularMarketPrice"]
      price ||= Array(result.dig("indicators", "quote", 0, "close")).compact.last
      price ||= meta["previousClose"]
      raise NotFoundError, "symbol #{requested} has no price data" if price.nil?

      {
        "symbol"   => (meta["symbol"] || requested).upcase,
        "price"    => price.to_f,
        "currency" => (meta["currency"] || "USD").upcase,
        "name"     => meta["longName"] || meta["shortName"],
        "exchange" => meta["exchangeName"],
        "as_of"    => (Time.at(meta["regularMarketTime"]).utc.iso8601 if meta["regularMarketTime"])
      }
    end

    def rapidapi_connection
      @rapidapi_connection ||= Faraday.new(url: @config.base_url, request: { timeout: @config.timeout }) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.adapter Faraday.default_adapter
      end
    end

    def perform_rapidapi_get(path, params)
      resp = rapidapi_connection.get(path, params) do |req|
        req.headers["X-RapidAPI-Key"]  = @config.api_key.to_s
        req.headers["X-RapidAPI-Host"] = @config.host.to_s
        req.headers["Accept"]          = "application/json"
      end

      case resp.status
      when 200..299 then resp.body
      when 404      then raise NotFoundError, "LSP 404 for #{path}"
      when 429      then raise RateLimitError, "LSP rate limit"
      else               raise HTTPError, "LSP HTTP #{resp.status}: #{resp.body}"
      end
    rescue Faraday::Error => e
      raise HTTPError, "LSP connection error: #{e.message}"
    end
  end
end