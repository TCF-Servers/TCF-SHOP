class AddColumnsToPlayersAndVotes < ActiveRecord::Migration[7.1]
  def change
    add_column :votes, :vote_valid, :boolean
    add_column :players, :votes_count, :integer
  end
end
