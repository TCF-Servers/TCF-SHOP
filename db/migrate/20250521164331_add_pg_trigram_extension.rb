class AddPgTrigramExtension < ActiveRecord::Migration[7.1]
  def change
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
  end
end
