module WalletOwner
  extend ActiveSupport::Concern

  included do
    has_one :wallet, as: :wallet_owner, dependent: :destroy, inverse_of: :wallet_owner
  end

  def wallet!
    wallet || create_wallet!(currency: "USD")
  end

  def balance_cents(currency: "USD")
    w = wallet
    return 0 unless w
    credits = WalletTransaction.where(wallet_id: w.id, currency: currency, type: "Credit").sum(:amount_cents)
    debits  = WalletTransaction.where(wallet_id: w.id, currency: currency, type: "Debit").sum(:amount_cents)
    credits - debits
  end
end