require 'rcon'

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
        POINTS_PER_VOTE = 100

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
                  player.in_game_name = in_game_name
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
                  
                  # Vérifier s'il y a des votes non traités pour ce joueur
                  process_pending_votes(player)
                end
              
              # Détecter les déconnexions
              elsif event.content.include?('Player logged off')
                # Extraire le nom du joueur
                in_game_name = event.content.match(/\*\*IngameName\*\*: `(.*?)`/).to_a[1]
                
                if in_game_name
                  puts "Joueur déconnecté: #{in_game_name}"
                  
                  # Trouver le joueur et mettre fin à sa session
                  player = Player.find_by(in_game_name: in_game_name)
                  if player
                    player.disconnect!
                    puts "Session de jeu terminée pour #{in_game_name}"
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
                        points_awarded: POINTS_PER_VOTE,
                        processed: false
                      )
                      
                      puts "Vote enregistré pour #{player.in_game_name} (#{recent_votes + 1}/#{MAX_VOTES_PER_PERIOD} dans les dernières #{VOTE_PERIOD_HOURS} heures)"
                      
                      process_vote(vote, player)
                    else
                      puts " Limite de votes atteinte pour #{player.in_game_name} (#{recent_votes}/#{MAX_VOTES_PER_PERIOD} dans les dernières #{VOTE_PERIOD_HOURS} heures)"
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
  
  private
  
  def self.process_vote(vote, player)
    return if vote.processed?
    
      # Utiliser le port RCON correspondant à la map actuelle
      map_port = MAP_PORTS[player.current_map] || ENV['ISLAND_WP_RCON_PORT'].to_i
      
      # Envoyer les points via RCON avec le bon port
      handle_rcon_command("AddPoints #{player.eos_id} #{vote.points_awarded}", map_port)
      
      # Marquer le vote comme traité
      vote.process!(player.current_map)
      puts "Points ajoutés pour #{player.in_game_name} sur la map #{player.current_map} (port: #{map_port})"
  end
  
  # def self.process_pending_votes(player)
  #   # Récupérer tous les votes non traités pour ce joueur
  #   pending_votes = player.votes.unprocessed
    
  #   if pending_votes.any?
  #     puts "Traitement de #{pending_votes.count} vote(s) en attente pour #{player.in_game_name}"
      
  #     pending_votes.each do |vote|
  #       process_vote(vote, player)
  #     end
  #   end
  # end
  
  def self.handle_rcon_command(command, port = nil)
    begin
      Timeout::timeout(50) do 
        client = Rcon::Client.new(
          host: ENV['RCON_HOST'],
          port: port || ENV['ISLAND_WP_RCON_PORT'].to_i,
          password: ENV['RCON_PASSWORD']
        )
        
        client.authenticate!(ignore_first_packet: false)
        response = client.execute(command)
        puts "Commande RCON exécutée: #{command} (port: #{port || ENV['ISLAND_WP_RCON_PORT']})"
        puts "Réponse: #{response}"
        
        # client.close
      end
    rescue => e
      puts "Erreur RCON: #{e.message}"
    end
  end
end