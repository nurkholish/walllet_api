module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate!
  end

  private

  def authenticate!
    token = bearer_token
    @current_session = Session.find_active_by_token(token)
    return if @current_session

    render json: { error: "unauthorized" }, status: :unauthorized
  end

  def current_user
    @current_session&.user
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    header.start_with?("Bearer ") ? header.sub("Bearer ", "") : nil
  end
end