class AddPlayerToUsers < ActiveRecord::Migration[7.1]
  def change
    add_reference :users, :player, foreign_key: true, index: { unique: true }
  end
end
