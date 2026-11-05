class Credit < WalletTransaction
  before_validation :normalize

  private

  def normalize
    self.source_wallet_id = nil
    self.wallet_id        = target_wallet_id if target_wallet_id
  end
end