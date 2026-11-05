class StocksController < ApplicationController
  include Authenticatable

  rescue_from LatestStockPrice::ConfigurationError, with: :render_bad_config
  rescue_from LatestStockPrice::RateLimitError,     with: :render_rate_limited
  rescue_from LatestStockPrice::NotFoundError,      with: :render_not_found
  rescue_from LatestStockPrice::HTTPError,          with: :render_upstream

  def price
    symbol = params.require(:stock)
    render json: LatestStockPrice.price(symbol)
  end

  def prices
    symbols = params.require(:stocks).to_s.split(",").map(&:strip).reject(&:empty?)
    raise ActionController::BadRequest, "stocks required" if symbols.empty?
    render json: LatestStockPrice.prices(symbols)
  end

  def price_all
    render json: LatestStockPrice.price_all
  end

  private

  def render_not_found(e)
    render json: { error: e.message }, status: :not_found
  end

  def render_rate_limited(e)
    render json: { error: e.message }, status: :too_many_requests
  end

  def render_upstream(e)
    if e.is_a?(LatestStockPrice::NotFoundError)
      return render json: { error: e.message }, status: :not_found
    end
    if e.is_a?(LatestStockPrice::RateLimitError)
      return render json: { error: e.message }, status: :too_many_requests
    end
    render json: { error: "upstream error", detail: e.message }, status: :bad_gateway
  end

  def render_bad_config(e)
    render json: { error: "config error", detail: e.message }, status: :internal_server_error
  end
end
