class CreatePlayers < ActiveRecord::Migration[7.1]
  def change
    create_table :players do |t|
      t.string :platform_name
      t.string :in_game_name
      t.string :eos_id
      t.string :tribe_id
      t.string :tribe_name
      t.string :discord_name
      t.string :discord_id
      t.timestamps
    end
  end
end
