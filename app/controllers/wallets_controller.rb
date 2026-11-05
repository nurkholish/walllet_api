class WalletsController < ApplicationController
  include Authenticatable

  before_action :load_owner

  def show
    wallet = @owner.wallet
    return render json: { error: "wallet not found" }, status: :not_found unless wallet
    render json: wallet_json(wallet)
  end

  def credit
    wallet = @owner.wallet!
    cents  = parse_amount_cents!(params.require(:amount))
    tx = WalletService.credit!(
      target_wallet: wallet, amount_cents: cents,
      reference: params[:reference], metadata: params.fetch(:metadata, {}).permit!.to_h,
      actor: current_user
    )
    render json: tx_json(tx), status: :created
  end

  def debit
    wallet = @owner.wallet!
    cents  = parse_amount_cents!(params.require(:amount))
    tx = WalletService.debit!(
      source_wallet: wallet, amount_cents: cents,
      reference: params[:reference], metadata: params.fetch(:metadata, {}).permit!.to_h,
      actor: current_user
    )
    render json: tx_json(tx), status: :created
  end

  private

  def load_owner
    klass = { "User" => User, "Team" => Team, "Stock" => Stock }[params[:owner_type].to_s]
    return render(json: { error: "unknown owner_type" }, status: :bad_request) unless klass
    @owner = klass.find(params[:owner_id])
  end

  def parse_amount_cents!(raw)
    case raw
    when Integer then raw
    when Float   then (raw * 100).round
    else              (BigDecimal(raw.to_s) * 100).round
    end
  rescue ArgumentError, TypeError
    raise ActionController::BadRequest, "invalid amount"
  end

  def wallet_json(w)
    {
      id: w.id, owner_type: w.wallet_owner_type, owner_id: w.wallet_owner_id,
      currency: w.currency, status: w.status,
      balance_cents: w.balance_cents, balance: format("%.2f", w.balance_cents / 100.0)
    }
  end

  def tx_json(t)
    {
      id: t.id, type: t.type, amount_cents: t.amount_cents, currency: t.currency,
      wallet_id: t.wallet_id, source_wallet_id: t.source_wallet_id,
      target_wallet_id: t.target_wallet_id, reference: t.reference,
      metadata: t.metadata, created_at: t.created_at
    }
  end
end