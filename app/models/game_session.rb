class GameSession < ApplicationRecord
  belongs_to :player
  
  # Scopes
  scope :online, -> { where(online: true) }
  scope :on_map, ->(map_name) { where(map_name: map_name) }
  
  # Méthodes
  def connect!(map_name)
    update(online: true, map_name: map_name)
  end
  
  def disconnect!
    update(online: false)
  end
end