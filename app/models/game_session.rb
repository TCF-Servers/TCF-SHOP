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

  # Durée de connexion formatée
  def online_duration
    return nil unless online?

    seconds = (Time.current - updated_at).to_i
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60

    if hours > 0
      "#{hours}h #{minutes.to_s.rjust(2, '0')}min"
    else
      "#{minutes}min"
    end
  end

  # Nom de map formaté (sans _WP)
  def formatted_map_name
    return nil unless map_name
    map_name.gsub("_WP", "").gsub("The", "The ").gsub("ScorchedEarth", "Scorched Earth").gsub("LostColony", "Lost Colony")
  end

  # Classe CSS pour la couleur de la map
  def map_css_class
    return "island" unless map_name
    case map_name.downcase
    when /island/ then "island"
    when /scorched/ then "scorched"
    when /aberration/ then "aberration"
    when /extinction/ then "extinction"
    when /genesis/ then "genesis"
    when /ragnarok/ then "ragnarok"
    when /valguero/ then "valguero"
    when /center/ then "center"
    when /lost/ then "lost-colony"
    when /astraeos/ then "astraeos"
    else "island"
    end
  end
end