namespace :cleanup do
  desc "Supprime les votes de plus de 2 mois"
  task old_votes: :environment do
    cutoff_date = 2.months.ago
    old_votes = Vote.where("created_at < ?", cutoff_date)
    count = old_votes.count

    if count.zero?
      puts "Aucun vote à supprimer."
    else
      puts "#{count} votes de plus de 2 mois trouvés."
      print "Confirmer la suppression ? (y/N): "
      confirmation = $stdin.gets.chomp.downcase

      if confirmation == "y"
        old_votes.in_batches(of: 1000).delete_all
        puts "#{count} votes supprimés."
      else
        puts "Suppression annulée."
      end
    end
  end

  desc "Supprime les votes de plus de 2 mois (sans confirmation)"
  task old_votes_force: :environment do
    cutoff_date = 2.months.ago
    count = Vote.where("created_at < ?", cutoff_date).count

    puts "Suppression de #{count} votes de plus de 2 mois..."
    Vote.where("created_at < ?", cutoff_date).in_batches(of: 1000).delete_all
    puts "Terminé."
  end

  desc "Supprime les joueurs sans connexion depuis le 1er février 2026"
  task inactive_players: :environment do
    cutoff = Date.new(2026, 2, 1).beginning_of_day
    scope = Player.left_joins(:game_session)
                  .where("game_sessions.id IS NULL OR game_sessions.updated_at < ?", cutoff)
    count = scope.count

    if count.zero?
      puts "Aucun joueur inactif à supprimer."
      next
    end

    puts "#{count} joueurs sans connexion depuis #{cutoff.to_date} trouvés."
    puts "Cela supprimera aussi leurs votes et sessions (cascade dependent: :destroy)."
    print "Confirmer la suppression ? (y/N): "
    confirmation = $stdin.gets.chomp.downcase

    if confirmation == "y"
      deleted = 0
      scope.find_each(batch_size: 500) do |player|
        player.destroy
        deleted += 1
      end
      puts "#{deleted} joueurs supprimés."
    else
      puts "Suppression annulée."
    end
  end

  desc "Supprime les joueurs sans connexion depuis le 1er février 2026 (sans confirmation)"
  task inactive_players_force: :environment do
    cutoff = Date.new(2026, 2, 1).beginning_of_day
    scope = Player.left_joins(:game_session)
                  .where("game_sessions.id IS NULL OR game_sessions.updated_at < ?", cutoff)

    puts "Suppression de #{scope.count} joueurs inactifs..."
    deleted = 0
    scope.find_each(batch_size: 500) do |player|
      player.destroy
      deleted += 1
    end
    puts "#{deleted} joueurs supprimés."
  end
end
