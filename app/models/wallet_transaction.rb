class WalletTransaction < ApplicationRecord
  CREDIT = "Credit".freeze
  DEBIT  = "Debit".freeze

  belongs_to :source_wallet, class_name: "Wallet", optional: true
  belongs_to :target_wallet, class_name: "Wallet", optional: true
  belongs_to :wallet,        class_name: "Wallet", optional: true
  belongs_to :actor,         class_name: "User",   optional: true

  validates :type,         presence: true, inclusion: { in: [CREDIT, DEBIT] }
  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :currency,     presence: true, inclusion: { in: %w[USD EUR GBP IDR] }
  validate  :wallet_scope_matches_currency
  validate  :source_and_target_valid

  scope :credits, -> { where(type: CREDIT) }
  scope :debits,  -> { where(type: DEBIT) }

  def credit?
    type == CREDIT
  end

  def debit?
    type == DEBIT
  end

  private

  def wallet_scope_matches_currency
    [source_wallet, target_wallet].compact.each do |w|
      errors.add(:currency, "mismatch with wallet #{w.id}") if w.currency != currency
    end
  end

  def source_and_target_valid
    if credit?
      errors.add(:source_wallet, "must be blank for credit") if source_wallet.present?
      errors.add(:target_wallet, "must be present for credit") if target_wallet.blank?
      errors.add(:wallet, "must equal target_wallet for credit") if wallet_id && wallet_id != target_wallet_id
    elsif debit?
      errors.add(:target_wallet, "must be blank for debit") if target_wallet.present?
      errors.add(:source_wallet, "must be present for debit") if source_wallet.blank?
      errors.add(:wallet, "must equal source_wallet for debit") if wallet_id && wallet_id != source_wallet_id
    end
  end
end