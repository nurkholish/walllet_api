class TransactionsController < ApplicationController
  include Authenticatable

  def index
    owner  = load_owner!
    wallet = owner.wallet
    return render json: [] unless wallet
    entries = wallet.ledger_entries.order(created_at: :desc).limit(200)
    render json: entries.map { |t| tx_json(t) }
  end

  def create
    from  = resolve_wallet!(params.require(:from))
    to    = resolve_wallet!(params.require(:to))
    cents = parse_amount_cents!(params.require(:amount))

    debit, credit = WalletService.transfer!(
      source_wallet: from, target_wallet: to,
      amount_cents: cents, reference: params[:reference],
      metadata: params.fetch(:metadata, {}).permit!.to_h, actor: current_user
    )
    render json: { debit: tx_json(debit), credit: tx_json(credit) }, status: :created
  end

  private

  def load_owner!
    klass = { "User" => User, "Team" => Team, "Stock" => Stock }[params[:owner_type].to_s]
    raise ActionController::BadRequest, "unknown owner_type" unless klass
    klass.find(params[:owner_id])
  end

  def resolve_wallet!(payload)
    klass = { "User" => User, "Team" => Team, "Stock" => Stock }[payload[:type].to_s]
    raise ActionController::BadRequest, "unknown type" unless klass
    owner = klass.find(payload[:id])
    owner.wallet || raise(ActiveRecord::RecordNotFound, "wallet not found for #{klass}##{payload[:id]}")
  end

  def parse_amount_cents!(raw)
    case raw
    when Integer then raw
    when Float   then (raw * 100).round
    else              (BigDecimal(raw.to_s) * 100).round
    end
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