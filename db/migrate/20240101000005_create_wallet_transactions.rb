class CreateWalletTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :wallet_transactions do |t|
      t.string   :type,            null: false
      t.integer  :amount_cents,    null: false
      t.string   :currency,        null: false, default: "USD"
      t.references :source_wallet, foreign_key: { to_table: :wallets }, null: true
      t.references :target_wallet, foreign_key: { to_table: :wallets }, null: true
      t.references :wallet,        foreign_key: true, null: true
      t.string   :reference,       null: true
      t.jsonb    :metadata,        null: false, default: "{}"
      t.references :actor, foreign_key: { to_table: :users }, null: true
      t.timestamps
    end

    add_index :wallet_transactions, :type
    add_index :wallet_transactions, [:wallet_id, :created_at]
    add_index :wallet_transactions, :reference

    add_check_constraint :wallet_transactions, "amount_cents > 0",
                         name: "wallet_transactions_amount_positive"
  end
end