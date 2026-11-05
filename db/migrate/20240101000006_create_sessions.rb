class CreateSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :sessions do |t|
      t.references :user, foreign_key: true, null: false
      t.string   :token_digest, null: false
      t.datetime :expires_at,   null: false
      t.datetime :revoked_at
      t.string   :ip
      t.string   :user_agent
      t.timestamps
    end
    add_index :sessions, :token_digest, unique: true
    add_index :sessions, [:user_id, :expires_at]
  end
end