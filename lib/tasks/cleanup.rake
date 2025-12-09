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
end
