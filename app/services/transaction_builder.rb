class TransactionBuilder
  def self.build(type:, amount_cents:, currency:, source_wallet: nil, target_wallet: nil, wallet: nil, actor: nil)
    klass = case type.to_s
            when "credit" then Credit
            when "debit"  then Debit
            else raise ArgumentError, "unknown type #{type}"
            end
    klass.new(amount_cents: amount_cents, currency: currency,
              source_wallet: source_wallet, target_wallet: target_wallet,
              wallet: wallet, actor: actor)
  end
end