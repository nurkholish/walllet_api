class WalletService
  class InsufficientFunds < StandardError; end
  class InvalidOperation  < StandardError; end

  def self.credit!(target_wallet:, amount_cents:, currency: nil, reference: nil, metadata: {}, actor: nil)
    new.credit!(target_wallet: target_wallet, amount_cents: amount_cents,
                currency: currency, reference: reference, metadata: metadata, actor: actor)
  end

  def self.debit!(source_wallet:, amount_cents:, currency: nil, reference: nil, metadata: {}, actor: nil, allow_negative: false)
    new.debit!(source_wallet: source_wallet, amount_cents: amount_cents, currency: currency,
               reference: reference, metadata: metadata, actor: actor, allow_negative: allow_negative)
  end

  def self.transfer!(source_wallet:, target_wallet:, amount_cents:, reference: nil, metadata: {}, actor: nil)
    new.transfer!(source_wallet: source_wallet, target_wallet: target_wallet,
                  amount_cents: amount_cents, reference: reference, metadata: metadata, actor: actor)
  end

  def credit!(target_wallet:, amount_cents:, currency: nil, reference: nil, metadata: {}, actor: nil)
    with_transaction do
      lock_and_assert_active!(target_wallet)
      currency ||= target_wallet.currency
      Credit.create!(
        target_wallet: target_wallet, wallet: target_wallet,
        amount_cents: amount_cents, currency: currency,
        reference: reference, metadata: metadata, actor: actor
      )
    end
  end

  def debit!(source_wallet:, amount_cents:, currency: nil, reference: nil, metadata: {}, actor: nil, allow_negative: false)
    with_transaction do
      lock_and_assert_active!(source_wallet)
      currency ||= source_wallet.currency
      if !allow_negative && source_wallet.balance_cents < amount_cents
        raise InsufficientFunds, "wallet #{source_wallet.id} balance #{source_wallet.balance_cents} < #{amount_cents}"
      end
      Debit.create!(
        source_wallet: source_wallet, wallet: source_wallet,
        amount_cents: amount_cents, currency: currency,
        reference: reference, metadata: metadata, actor: actor
      )
    end
  end

  def transfer!(source_wallet:, target_wallet:, amount_cents:, reference: nil, metadata: {}, actor: nil)
    raise InvalidOperation, "source and target must differ" if source_wallet.id == target_wallet.id
    raise InvalidOperation, "currency mismatch" if source_wallet.currency != target_wallet.currency

    with_transaction do
      ids = [source_wallet.id, target_wallet.id].sort
      Wallet.where(id: ids).lock.load

      lock_and_assert_active!(source_wallet)
      lock_and_assert_active!(target_wallet)

      if source_wallet.balance_cents < amount_cents
        raise InsufficientFunds, "wallet #{source_wallet.id} insufficient funds"
      end

      ref = reference || SecureRandom.uuid
      debit  = Debit.create!(
        source_wallet: source_wallet,
        wallet:        source_wallet,
        amount_cents:  amount_cents,
        currency:      source_wallet.currency,
        reference:     ref, metadata: metadata.merge(direction: "debit"), actor: actor
      )
      credit = Credit.create!(
        target_wallet: target_wallet,
        wallet:        target_wallet,
        amount_cents:  amount_cents,
        currency:      target_wallet.currency,
        reference:     ref, metadata: metadata.merge(direction: "credit"), actor: actor
      )
      [debit, credit]
    end
  end

  private

  def with_transaction(&block)
    ActiveRecord::Base.transaction(requires_new: true, isolation: :read_committed, &block)
  end

  def lock_and_assert_active!(wallet)
    wallet.lock!
    raise InvalidOperation, "wallet #{wallet.id} is not active" unless wallet.active?
  end
end