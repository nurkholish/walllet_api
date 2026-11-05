class Wallet < ApplicationRecord
  belongs_to :wallet_owner, polymorphic: true

  has_many :transactions_as_source, class_name: "WalletTransaction",
           foreign_key: :source_wallet_id, dependent: :restrict_with_error, inverse_of: :source_wallet
  has_many :transactions_as_target, class_name: "WalletTransaction",
           foreign_key: :target_wallet_id, dependent: :restrict_with_error, inverse_of: :target_wallet
  has_many :ledger_entries, class_name: "WalletTransaction", foreign_key: :wallet_id,
           dependent: :restrict_with_error, inverse_of: :wallet

  enum :status, { active: "active", suspended: "suspended" }, default: "active", validate: true

  validates :currency, presence: true, inclusion: { in: %w[USD EUR GBP IDR] }
  validates :status, presence: true
  validates :wallet_owner_id, uniqueness: { scope: [:wallet_owner_type, :currency] }

  def balance_cents
    ledger_entries.sum(
      Arel.sql("CASE WHEN type = 'Credit' THEN amount_cents ELSE -amount_cents END")
    )
  end

  def active?
    status == "active"
  end
end