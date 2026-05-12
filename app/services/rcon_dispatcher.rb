require "rcon"
require "timeout"

# Envoi de commandes RCON aux serveurs ARK depuis l'app web.
# (Le bot Discord garde sa propre implémentation dans lib/tasks/discord_bot.rake.)
class RconDispatcher
  # map ARK (game_session.map_name) => variable d'env du port RCON correspondant
  MAP_PORT_ENVS = {
    "TheIsland_WP"     => "ISLAND_WP_RCON_PORT",
    "TheCenter_WP"     => "CENTER_WP_RCON_PORT",
    "ScorchedEarth_WP" => "SCORCHED_EARTH_WP_RCON_PORT",
    "Aberration_WP"    => "ABERRATION_WP_RCON_PORT",
    "Ragnarok_WP"      => "RAGNAROK_WP_RCON_PORT",
    "LostColony_WP"    => "LOST_COLONY_WP_RCON_PORT",
    "Extinction_WP"    => "EXTINCTION_WP_RCON_PORT",
    "Astraeos_WP"      => "ASTRAEOS_WP_RCON_PORT",
    "Valguero_WP"      => "VALGUERO_WP_RCON_PORT",
  }.freeze

  DEFAULT_PORT_ENV = "ISLAND_WP_RCON_PORT"

  Result = Struct.new(:success, :response, :error, keyword_init: true) do
    def success? = success
  end

  class << self
    def timeout
      ENV.fetch("RCON_TIMEOUT", 5).to_i
    end

    def port_for(map_name)
      ENV[MAP_PORT_ENVS.fetch(map_name, DEFAULT_PORT_ENV)].to_i
    end

    # Exécute une commande RCON brute. Ne lève jamais : renvoie toujours un Result.
    def execute(command, map_name: nil, port: nil)
      target_port = port || port_for(map_name)
      client = nil
      Timeout.timeout(timeout) do
        client = Rcon::Client.new(host: ENV["RCON_HOST"], port: target_port, password: ENV["RCON_PASSWORD"])
        client.authenticate!(ignore_first_packet: false)
        body = client.execute(command)&.body.to_s
        Rails.logger.info("[RCON] #{command} (port #{target_port}) => #{body.inspect}")
        Result.new(success: true, response: body)
      end
    rescue Timeout::Error
      Rails.logger.warn("[RCON] timeout (#{timeout}s) sur: #{command}")
      Result.new(success: false, error: "Timeout RCON (#{timeout}s)")
    rescue StandardError => e
      Rails.logger.warn("[RCON] échec sur '#{command}': #{e.class}: #{e.message}")
      Result.new(success: false, error: "#{e.class}: #{e.message}")
    ensure
      begin
        client&.end_session!
      rescue StandardError
        nil
      end
    end

    # Exécute la commande puis journalise un RconExecution. Renvoie le RconExecution.
    def execute_and_log(command, map_name:, user:, player: nil, template: nil)
      result = execute(command, map_name: map_name)
      RconExecution.create!(
        user: user,
        player: player,
        rcon_command_template: template,
        map: map_name,
        full_command: command,
        response: result.response.presence || result.error,
        success: result.success?
      )
    end
  end
end
