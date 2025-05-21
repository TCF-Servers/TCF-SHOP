class Vote < ApplicationRecord
  belongs_to :player
  
  # Scopes
  scope :recent, ->(hours = 2) { where('created_at >= ?', hours.hours.ago) }
  scope :processed, -> { where(processed: true) }
  scope :unprocessed, -> { where(processed: false) }
  scope :from_source, ->(source) { where(source: source) }
  
  # Validations
  validates :player_id, presence: true
  validates :points_awarded, numericality: { greater_than: 0 }
  
  # Méthodes
  def process!(map_name = nil)
    update(processed: true, map_name: map_name)
  end
  
  # Méthode de classe pour vérifier si un joueur peut voter
  def self.player_can_vote?(player, hours = 2, max_votes = 3)
    return false unless player
    player.votes.recent(hours).count < max_votes
  end
end
