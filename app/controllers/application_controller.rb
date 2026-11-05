class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound,          with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid,           with: :render_unprocessable
  rescue_from ActionController::ParameterMissing,    with: :render_bad_request
  rescue_from WalletService::InsufficientFunds,      with: :render_unprocessable
  rescue_from WalletService::InvalidOperation,       with: :render_unprocessable

  private

  def render_not_found(e)
    render json: { error: e.message }, status: :not_found
  end

  def render_unprocessable(e)
    errors = e.respond_to?(:record) && e.record ? e.record.errors.full_messages : [e.message]
    render json: { errors: errors }, status: :unprocessable_entity
  end

  def render_bad_request(e)
    render json: { error: e.message }, status: :bad_request
  end
end