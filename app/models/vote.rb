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
    player.can_vote?(hours, max_votes)
  end


  def self.current_month_votes_count
    where('created_at >= ?', Time.current.beginning_of_month - 2.hours).count
  end

  def self.current_month_points
    base_points = 150
    votes_count = current_month_votes_count
    
    case votes_count
    when 1000...2500 then (base_points * 1.10).ceil
    when 2500...5000 then (base_points * 1.25).ceil  
    when 5000...7500 then (base_points * 1.50).ceil  
    when 7500...10000 then (base_points * 1.75).ceil 
    when 10000..Float::INFINITY then (base_points * 2.00).ceil 
    else base_points
    end
  end
end
