class CreateBannedPlayers < ActiveRecord::Migration[7.1]
  def change
    create_table :banned_players do |t|
      t.string :eos_id, null: false
      t.text :reason
      t.datetime :expires_at
      t.references :banned_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :player, foreign_key: { on_delete: :nullify }

      t.timestamps
    end

    add_index :banned_players, :eos_id, unique: true
    add_index :banned_players, :expires_at
  end
end
