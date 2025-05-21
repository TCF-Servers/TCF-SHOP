class CreateGameSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :game_sessions do |t|
      t.references :player, null: false, foreign_key: true, index: { unique: true }
      t.string :map_name
      t.boolean :online, default: false
      t.timestamps
    end
  end
end
