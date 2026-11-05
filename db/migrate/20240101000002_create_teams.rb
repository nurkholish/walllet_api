class CreateTeams < ActiveRecord::Migration[7.1]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.references :owner, foreign_key: { to_table: :users }, null: true
      t.timestamps
    end
    add_index :teams, :slug, unique: true
  end
end