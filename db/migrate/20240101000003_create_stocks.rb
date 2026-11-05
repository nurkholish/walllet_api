class CreateStocks < ActiveRecord::Migration[7.1]
  def change
    create_table :stocks do |t|
      t.string  :symbol,           null: false
      t.string  :name,             null: false
      t.integer :last_price_cents, null: false, default: 0
      t.timestamps
    end
    add_index :stocks, :symbol, unique: true
  end
end