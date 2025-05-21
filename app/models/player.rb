class Player < ApplicationRecord
  has_one :game_session, dependent: :destroy
  has_many :votes, dependent: :destroy
  
  # Configuration de pg_search
  include PgSearch::Model
  pg_search_scope :search_by_name,
                  against: :in_game_name,
                  using: {
                    tsearch: { prefix: true, any_word: true },
                    trigram: { threshold: 0.3 }
                  }
  
  # Méthodes pour la gestion des sessions
  def online?
    game_session&.online? || false
  end
  
  def current_map
    game_session&.map_name
  end
  
  def connect!(map_name)
    # Créer ou mettre à jour la session
    if game_session.nil?
      create_game_session(map_name: map_name, online: true)
    else
      game_session.connect!(map_name)
    end
  end
  
  def disconnect!
    game_session&.disconnect!
  end
  
  # Méthode pour vérifier si le joueur peut voter
  def can_vote?(hours = 2, max_votes = 3)
    votes.recent(hours).count < max_votes
  end
  
  # Méthode pour obtenir le nombre de votes récents
  def recent_votes_count(hours = 2)
    votes.recent(hours).count
  end
  
  # Méthode de classe pour rechercher un joueur de manière flexible
  def self.find_by_flexible_name(name)
    # Essayer une correspondance exacte d'abord
    player = find_by(in_game_name: name)
    return player if player
    
    # Essayer une correspondance insensible à la casse
    player = where("LOWER(in_game_name) = LOWER(?)", name).first
    return player if player
    
    # Utiliser pg_search pour une recherche plus flexible
    first_word = name.split(/\s+|[^a-zA-Z0-9]/).first
    return nil if first_word.blank?
    
    search_by_name(first_word).first
  end
end