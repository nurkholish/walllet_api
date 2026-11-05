class Debit < WalletTransaction
  before_validation :normalize

  private

  def normalize
    self.target_wallet_id = nil
    self.wallet_id        = source_wallet_id if source_wallet_id
  end
end