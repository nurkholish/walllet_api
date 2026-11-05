class Stock < ApplicationRecord
  include WalletOwner

  validates :symbol, presence: true, uniqueness: { case_sensitive: false },
                     format: { with: /\A[A-Z\.\-]{1,12}\z/ }
  validates :name, presence: true
  validates :last_price_cents, numericality: { greater_than_or_equal_to: 0 }

  before_validation { self.symbol = symbol.to_s.strip.upcase }
end