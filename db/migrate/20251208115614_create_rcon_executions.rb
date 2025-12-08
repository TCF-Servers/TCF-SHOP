class CreateRconExecutions < ActiveRecord::Migration[7.1]
  def change
    create_table :rcon_executions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :player, foreign_key: true
      t.references :rcon_command_template, foreign_key: true
      t.string :map, null: false
      t.string :full_command, null: false
      t.text :response
      t.boolean :success, null: false

      t.timestamps
    end

    add_index :rcon_executions, :success
    add_index :rcon_executions, :created_at
  end
end
