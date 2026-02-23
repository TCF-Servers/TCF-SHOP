class AddMissingIndexes < ActiveRecord::Migration[7.1]
  def change
    add_index :players, :eos_id, unique: true
    add_index :votes, :vote_valid
  end
end
