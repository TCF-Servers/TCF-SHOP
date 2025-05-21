class CreateVotes < ActiveRecord::Migration[7.1]
  def change
    create_table :votes do |t|
      t.references :player, null: false, foreign_key: true
      t.string :source, default: "topserveur" 
      t.integer :points_awarded, default: 100 
      t.boolean :processed, default: false     
      t.string :map_name
      t.timestamps
    end
    
    add_index :votes, [:player_id, :created_at]
  end
end
