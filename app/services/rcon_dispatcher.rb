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
  ALL_MAPS_LABEL = "Toutes les maps".freeze

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

    # { map_name => port } pour toutes les maps dont le port est réellement configuré.
    def all_map_ports
      MAP_PORT_ENVS.filter_map do |map_name, env_key|
        port = ENV[env_key].to_i
        [map_name, port] unless port.zero?
      end.to_h
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
      Rails.logger.warn("[RCON] timeout (#{timeout}s) sur: #{command} (port #{target_port})")
      Result.new(success: false, error: "Timeout RCON (#{timeout}s)")
    rescue StandardError => e
      Rails.logger.warn("[RCON] échec sur '#{command}' (port #{target_port}): #{e.class}: #{e.message}")
      Result.new(success: false, error: "#{e.class}: #{e.message}")
    ensure
      begin
        client&.end_session!
      rescue StandardError
        nil
      end
    end

    # Exécute la commande sur toutes les maps configurées, en parallèle.
    # Renvoie un Hash { map_name => Result }.
    def execute_on_all_maps(command)
      ports = all_map_ports
      return {} if ports.empty?

      results = {}
      mutex = Mutex.new
      ports.map do |map_name, port|
        Thread.new do
          res = execute(command, port: port)
          mutex.synchronize { results[map_name] = res }
        end
      end.each(&:join)
      results
    end

    # Exécute la commande sur une map puis journalise un RconExecution. Renvoie le RconExecution.
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

    # Exécute la commande sur toutes les maps puis journalise UN RconExecution agrégé.
    # Renvoie le Hash { map_name => Result }.
    def execute_and_log_all(command, user:, player: nil, template: nil)
      results = execute_on_all_maps(command)
      summary = results.map { |map_name, res| "#{map_name}: #{res.success? ? "OK" : res.error}" }.join(" | ")
      RconExecution.create!(
        user: user,
        player: player,
        rcon_command_template: template,
        map: ALL_MAPS_LABEL,
        full_command: command,
        response: summary.presence || "Aucun serveur RCON configuré",
        success: results.any? && results.values.all?(&:success?)
      )
      results
    end
  end
end
