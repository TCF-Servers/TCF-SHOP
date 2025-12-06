# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require 'rcon'
require 'timeout'

# Mapping des maps vers les ports RCON (identique au bot Discord)
MAP_PORTS = {
  'TheIsland_WP' => ENV['ISLAND_WP_RCON_PORT'].to_i,
  'TheCenter_WP' => ENV['CENTER_WP_RCON_PORT'].to_i,
  'ScorchedEarth_WP' => ENV['SCORCHED_EARTH_WP_RCON_PORT'].to_i,
  'Aberration_WP' => ENV['ABERRATION_WP_RCON_PORT'].to_i,
  'Ragnarok_WP' => ENV['RAGNAROK_WP_RCON_PORT'].to_i,
  'LostColonny_WP' => ENV['LOST_COLONY_WP_RCON_PORT'].to_i,
  'Extinction_WP' => ENV['EXTINCTION_WP_RCON_PORT'].to_i,
  'Astraeos_WP' => ENV['ASTRAEOS_WP_RCON_PORT'].to_i,
  'Valguero_WP' => ENV['VALGUERO_WP_RCON_PORT'].to_i,
}

# Récupération des données (uniquement les votes valides)
data = Vote
  .joins(player: :game_session)
  .where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
  .where(vote_valid: true)
  .group("players.eos_id, game_sessions.map_name, game_sessions.online")
  .select("players.eos_id, COUNT(votes.id) as vote_count, game_sessions.map_name, game_sessions.online")
  .map do |v|
    rcon_port = if v.online
                  MAP_PORTS[v.map_name] || ENV['ISLAND_WP_RCON_PORT'].to_i
                else
                  ENV['ISLAND_WP_RCON_PORT'].to_i
                end

    {
      eos_id: v.eos_id,
      vote_count: v.vote_count,
      rcon_port: rcon_port
    }
  end

# Fonction pour exécuter une commande RCON
def execute_rcon_command(command, port)
  begin
    Timeout::timeout(5) do
      client = Rcon::Client.new(
        host: ENV['RCON_HOST'],
        port: port,
        password: ENV['RCON_PASSWORD']
      )
      client.authenticate!(ignore_first_packet: false)
      puts "Commande RCON: #{command} (port: #{port})"
      response = client.execute(command)
      puts "Réponse: #{response.body}"
      return true
    end
  rescue Timeout::Error
    puts "Timeout RCON (5s) pour la commande: #{command} sur le port #{port}"
    return false
  rescue => e
    puts "Erreur RCON: #{e.message}"
    return false
  end
end

# Itération sur les données et exécution des commandes RCON
data.each do |player_data|
  eos_id = player_data[:eos_id]
  vote_count = player_data[:vote_count]
  rcon_port = player_data[:rcon_port]
  points = 150 * vote_count

  command = "AddPoints #{eos_id} #{points}"

  puts "Traitement du joueur #{eos_id}: #{vote_count} votes = #{points} points (port: #{rcon_port})"

  success = execute_rcon_command(command, rcon_port)

  if success
    puts "✓ Points ajoutés avec succès pour #{eos_id}"
  else
    puts "✗ Échec de l'ajout de points pour #{eos_id}"
  end

  # Petite pause pour éviter de surcharger le serveur RCON
  sleep 0.5
end

puts "Traitement terminé: #{data.size} joueurs traités"
