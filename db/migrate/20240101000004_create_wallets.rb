class CreateWallets < ActiveRecord::Migration[7.1]
  def change
    create_table :wallets do |t|
      t.references :wallet_owner, polymorphic: true, null: false, index: true
      t.string :currency, null: false, default: "USD"
      t.string :status,   null: false, default: "active"
      t.timestamps
    end
    add_index :wallets, [:wallet_owner_type, :wallet_owner_id, :currency],
              unique: true, name: "index_wallets_on_owner_and_currency"
  end
end