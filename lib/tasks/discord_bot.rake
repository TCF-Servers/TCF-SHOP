require 'rcon'
require 'timeout'


namespace :discord do
  desc 'Start Discord bot'
  task start: :environment do
    # Boucle de redémarrage en cas d'erreur
    loop do
      begin
        puts "Démarrage du bot Discord à #{Time.current}"

        bot = Discordrb::Bot.new(
          token: ENV['DISCORD_BOT_TOKEN'],
          intents: [:server_messages, :message_content, :guilds] # Intents nécessaires
        )

        # Définir les constantes pour les channels
        vote_channel_id = ENV['VOTE_CHANNEL_ID']
        joinleave_channel_id = ENV['JOINLEAVE_CHANNEL_ID']

        # Mapping des maps vers les ports RCON
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
          # Ajoutez d'autres maps avec leurs ports respectifs
          # 'Ragnarok_WP' => ENV['RAGNAROK_WP_RCON_PORT'].to_i,
          # 'Aberration_WP' => ENV['ABERRATION_WP_RCON_PORT'].to_i,
          # etc.
        }

        # Configuration des votes
        MAX_VOTES_PER_PERIOD = 3
        VOTE_PERIOD_HOURS = 2
        UNAUTHORIZED_IN_GAME_NAME = [
          "survivor",
          "survivant",
          "joueur",
          "un joueur",
          "joueurs",
          "player",
          "humain",
          "humains",
          "human",
        ]

        # Ajouter un gestionnaire d'erreurs pour éviter que le bot ne se ferme
        bot.heartbeat do
          puts "Bot Discord toujours en vie - #{Time.current}"
        end

        # Ajouter un gestionnaire pour les déconnexions
        bot.disconnected do |event|
          puts "Bot déconnecté à #{Time.current} - Tentative de reconnexion..."
          sleep 5
          # La boucle principale va gérer la reconnexion
          raise "Déconnexion détectée, redémarrage du bot"
        end

        bot.message do |event|
          begin
            # Traitement pour le channel de connexion/déconnexion
            if event.channel.id.to_s == joinleave_channel_id
              puts "Message dans le channel joinleave: #{event.content}"

              # Extraire le nom de la map (au début du message)
              map_name = event.content.match(/\*\*(.*?)_WP:\*\*/).to_a[1]
              map_name = "#{map_name}_WP" if map_name

              # Détecter les connexions
              if event.content.include?('Player logged in')
                # Extraire les informations du joueur avec la nouvelle regex
                platform_name = event.content.match(/\*\*PlatformName:\*\* `(.*?)`/).to_a[1]
                in_game_name = event.content.match(/\*\*IngameName\*\*: `(.*?)`/).to_a[1]
                eos_id = event.content.match(/\*\*EOS:\*\* `(.*?)`/).to_a[1]
                tribe_id = event.content.match(/\*\*TribeId:\*\* `(.*?)`/).to_a[1]
                tribe_name = event.content.match(/\*\*TribeName:\*\* `(.*?)`/).to_a[1]
                discord_name = event.content.match(/\*\*DiscordName:\*\* `(.*?)`/).to_a[1]
                discord_id = event.content.match(/\*\*DiscordId:\*\* `(.*?)`/).to_a[1]

                if eos_id
                  puts "Joueur connecté: #{in_game_name} (EOS: #{eos_id}) sur #{map_name}"

                  # Chercher le joueur par EOS ID ou créer une nouvelle instance
                  player = Player.find_or_initialize_by(eos_id: eos_id)

                  # Mettre à jour les informations du joueur
                  if player.in_game_name == "Survivor" || player.in_game_name == "survivor" || player.in_game_name.nil?
                    player.in_game_name = in_game_name
                  end

                  player.platform_name = platform_name
                  player.tribe_id = tribe_id
                  player.tribe_name = tribe_name
                  player.discord_name = discord_name
                  player.discord_id = discord_id

                  # Sauvegarder le joueur
                  player.save

                  # Créer une nouvelle session de jeu
                  player.connect!(map_name)
                  puts "Session de jeu créée pour #{in_game_name} sur #{map_name}"

                  # Traiter les votes non processed lors de la connexion
                  unprocessed_votes = player.votes.unprocessed.where(vote_valid: true)
                  if unprocessed_votes.any?
                    puts "Traitement des votes non processed pour #{player.in_game_name} lors de la connexion (#{unprocessed_votes.count} votes)"
                    process_votes_batch(unprocessed_votes, player)
                  end
                end

              # Détecter les déconnexions
              elsif event.content.include?('Player logged off')
                # Extraire le nom du joueur
                in_game_name = event.content.match(/\*\*IngameName\*\*: `(.*?)`/).to_a[1]
                eos_id = event.content.match(/\*\*EOS:\*\* `(.*?)`/).to_a[1]

                if eos_id
                  puts "Joueur déconnecté: #{in_game_name} (EOS: #{eos_id})"

                  # Trouver le joueur et mettre fin à sa session
                  player = Player.find_by(eos_id: eos_id)
                  if player
                    player.disconnect!
                    puts "Session de jeu terminée pour #{player.in_game_name} (EOS: #{eos_id})"
                  end
                end
              end
            end

            # Traitement pour le channel de vote
            if event.channel.id.to_s == vote_channel_id
              puts "Message reçu dans le channel de vote: #{event.content}"

              # Vérifier si c'est un message de vote (à adapter selon le format exact des messages)
              if event.content.include?('vient de voter pour le serveur')
                # Extraire le nom du joueur (à adapter selon le format exact)
                player_name = event.content.match(/^(.*?) vient de voter/).to_a[1]

                if player_name
                  puts "Vote détecté pour le joueur: #{player_name}"

                  # Utiliser la recherche flexible pour trouver le joueur
                  player = Player.search_by_name(player_name).first

                  if player
                    puts "Joueur trouvé: #{player.in_game_name} (correspondance avec '#{player_name}')"

                    # Vérifier si le joueur a déjà voté trop de fois récemment
                    recent_votes = player.recent_votes_count(VOTE_PERIOD_HOURS)

                    if recent_votes < MAX_VOTES_PER_PERIOD
                      # Créer un nouveau vote
                      vote = player.votes.create!(
                        source: "topserveur",
                        points_awarded: Vote.current_month_points,
                        processed: false,
                        vote_valid: true
                      )

                      puts "Vote enregistré pour #{player.in_game_name} (#{recent_votes + 1}/#{MAX_VOTES_PER_PERIOD} dans les dernières #{VOTE_PERIOD_HOURS} heures)"

                      if UNAUTHORIZED_IN_GAME_NAME.include?(player.in_game_name)
                        puts "Vote non traité pour #{player.in_game_name} (nom non autorisé)"
                        vote.destroy
                      else
                        process_votes_batch([vote], player)
                      end
                    else
                      puts " Limite de votes atteinte pour #{player.in_game_name} (#{recent_votes}/#{MAX_VOTES_PER_PERIOD} dans les dernières #{VOTE_PERIOD_HOURS} heures). Création d'un vote non valide."
                      vote = player.votes.create!(
                        source: "topserveur",
                        points_awarded: Vote.current_month_points,
                        processed: true,
                        vote_valid: false
                      )
                    end
                  else
                    puts "Joueur non trouvé dans la base de données: #{player_name}"
                  end
                end
              end
            end
          rescue => e
            # Capturer les erreurs dans le traitement des messages pour éviter que le bot ne se ferme
            puts "Erreur lors du traitement d'un message: #{e.message}"
            puts e.backtrace.join("\n")
          end
        end

        puts 'Bot Discord démarré!'

        # Define helper methods within the task scope
        def process_vote(vote, player)
          return if vote.processed?

          # Utiliser le port RCON correspondant à la map actuelle
          map_port = MAP_PORTS[player.current_map] || ENV['ISLAND_WP_RCON_PORT'].to_i

          # Envoyer les points via RCON avec le bon port
          success = handle_rcon_command("AddPoints #{player.eos_id} #{vote.points_awarded}", map_port)

          if success
            # Marquer le vote comme traité seulement si RCON a réussi
            vote.process!(player.current_map)
            puts "Points ajoutés pour #{player.in_game_name} sur la map #{player.current_map} (port: #{map_port})"
            return true
          else
            puts "Échec de l'ajout de points pour #{player.in_game_name} - le vote reste non processed pour retraitement ultérieur"
            return false
          end
        end

        def handle_rcon_command(command, port = nil, vote = nil)
          begin
            Timeout::timeout(5) do
              client = Rcon::Client.new(
                host: ENV['RCON_HOST'],
                port: port || ENV['ISLAND_WP_RCON_PORT'].to_i,
                password: ENV['RCON_PASSWORD']
              )
              client.authenticate!(ignore_first_packet: false)
              puts "Commande RCON: #{command} (port: #{port} | client: #{client.send(:host)}:#{client.send(:port)}, #{client.send(:socket)})"
              response = client.execute(command)
              puts "Commande RCON exécutée: #{command} (port: #{port || ENV['ISLAND_WP_RCON_PORT']})"
              puts "Réponse: #{response.body}"

              return true
            end
          rescue Timeout::Error
            puts "Timeout RCON (5s) pour la commande: #{command}"
            return false
          rescue => e
            puts "Erreur RCON: #{e.message}"
            return false
          end
        end

        def process_votes_batch(votes, player)
          return if votes.empty?

          processed_count = 0

          # Traiter les votes de manière asynchrone avec un pool de threads
          threads = []
          votes.each do |vote|
            threads << Thread.new do
              if process_vote(vote, player)
                processed_count += 1
              end
            end

            # Limiter le nombre de threads simultanés
            if threads.size >= 3
              threads.each(&:join)
              threads.clear
            end
          end

          # Attendre les derniers threads
          threads.each(&:join)

          # Mettre à jour votes_count en une seule fois
          if processed_count > 0
            player.increment!(:votes_count, processed_count)
            puts "#{processed_count} votes traités pour #{player.in_game_name}"
          end
        end

        # Démarrer le bot dans un thread pour pouvoir le surveiller
        bot_thread = Thread.new { bot.run }

        # Vérifier régulièrement si le thread du bot est toujours en vie
        loop do
          sleep 60
          if !bot_thread.alive?
            puts "Le thread du bot n'est plus actif, redémarrage..."
            raise "Thread du bot mort, redémarrage"
          end
        end

      rescue => e
        # En cas d'erreur, attendre un peu et redémarrer le bot
        puts "Erreur dans le bot Discord: #{e.message}"
        puts e.backtrace.join("\n")
        puts "Redémarrage dans 30 secondes..."
        sleep 30
      end
    end

  end
end
