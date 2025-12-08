class CreateRconCommandTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :rcon_command_templates do |t|
      t.string :name, null: false
      t.string :command_template, null: false
      t.text :description
      t.integer :required_role, default: 1, null: false
      t.boolean :requires_player, default: true, null: false
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    add_index :rcon_command_templates, :name, unique: true
    add_index :rcon_command_templates, :enabled
  end
end
