# Seed pour créer des joueurs de test en ligne

MAPS = %w[
  TheIsland_WP
  TheCenter_WP
  ScorchedEarth_WP
  Aberration_WP
  Ragnarok_WP
  Extinction_WP
  Valguero_WP
]

PLAYER_NAMES = %w[
  DarkWolf
  ShadowHunter
  NightRaven
  StormBreaker
  IronClaw
  FireDragon
  IcePhoenix
  ThunderBolt
  SilentArrow
  BloodMoon
  CrimsonBlade
  FrostBite
  VenomStrike
  SteelFang
  GhostRider
  DeathBringer
  WarHammer
  NightStalker
  SoulReaper
  DoomSlayer
]

puts "Suppression des anciennes données..."
GameSession.destroy_all
Player.destroy_all

puts "Création de #{PLAYER_NAMES.size} joueurs..."

PLAYER_NAMES.each_with_index do |name, i|
  player = Player.create!(
    platform_name: "Steam_#{name.downcase}",
    in_game_name: name,
    eos_id: "00#{SecureRandom.hex(16)}",
    tribe_id: rand(1000..9999).to_s,
    tribe_name: ["Les Guerriers", "Shadow Tribe", "Phoenix Rising", "Iron Legion", "Night Wolves"].sample,
    discord_name: "#{name.downcase}##{rand(1000..9999)}",
    discord_id: rand(100000000000000000..999999999999999999).to_s,
    votes_count: rand(0..50)
  )

  # Tous les joueurs sont en ligne
  player.create_game_session!(
    map_name: MAPS.sample,
    online: true
  )

  puts "  - #{name} créé (#{player.current_map})"
end

puts "Seed terminé: #{Player.count} joueurs créés, #{GameSession.where(online: true).count} en ligne"

# Création des utilisateurs admin
puts "\nCréation des utilisateurs admin..."
RconExecution.destroy_all
RconCommandTemplate.destroy_all
User.where.not(role: :superadmin).destroy_all

admins = [
  { email: "admin@tcf.com", password: "password123", role: :admin },
  { email: "moderator@tcf.com", password: "password123", role: :admin },
  { email: "manager@tcf.com", password: "password123", role: :superadmin }
]

created_admins = admins.map do |admin_data|
  user = User.find_or_create_by!(email: admin_data[:email]) do |u|
    u.password = admin_data[:password]
    u.role = admin_data[:role]
  end
  puts "  - #{user.email} (#{user.role})"
  user
end

# Création des templates de commandes RCON
puts "\nCréation des templates RCON..."
templates = [
  { name: "AddPoints", command_template: "AddPoints {eos_id} {amount}", description: "Ajouter des points à un joueur", required_role: :admin, requires_player: true },
  { name: "GiveItem", command_template: "GiveItemToPlayer {eos_id} {item_id} {quantity} {quality}", description: "Donner un item à un joueur", required_role: :admin, requires_player: true },
  { name: "Kick", command_template: "KickPlayer {eos_id}", description: "Expulser un joueur du serveur", required_role: :admin, requires_player: true },
  { name: "Ban", command_template: "BanPlayer {eos_id}", description: "Bannir un joueur", required_role: :superadmin, requires_player: true },
  { name: "Broadcast", command_template: "Broadcast {message}", description: "Envoyer un message global", required_role: :admin, requires_player: false },
  { name: "SaveWorld", command_template: "SaveWorld", description: "Sauvegarder le monde", required_role: :superadmin, requires_player: false }
]

created_templates = templates.map do |t|
  template = RconCommandTemplate.create!(t)
  puts "  - #{template.name}"
  template
end

# Création des exécutions RCON
puts "\nCréation des exécutions RCON..."
players = Player.all.to_a

executions_data = [
  { template: "AddPoints", command: "AddPoints {eos_id} 500", success: true, response: "Points added successfully" },
  { template: "AddPoints", command: "AddPoints {eos_id} 1000", success: true, response: "Points added successfully" },
  { template: "GiveItem", command: "GiveItemToPlayer {eos_id} PrimalItemResource_Metal_C 100 0", success: true, response: "Item given" },
  { template: "Kick", command: "KickPlayer {eos_id}", success: true, response: "Player kicked" },
  { template: "Broadcast", command: "Broadcast Maintenance dans 30 minutes!", success: true, response: "Message sent" },
  { template: "AddPoints", command: "AddPoints {eos_id} 250", success: false, response: "Player not found" },
  { template: "SaveWorld", command: "SaveWorld", success: true, response: "World saved" },
  { template: "GiveItem", command: "GiveItemToPlayer {eos_id} PrimalItemAmmo_Bullet_C 50 0", success: true, response: "Item given" },
  { template: nil, command: "ListPlayers", success: true, response: "20 players online" },
  { template: "AddPoints", command: "AddPoints {eos_id} 750", success: true, response: "Points added successfully" },
  { template: "Kick", command: "KickPlayer {eos_id}", success: false, response: "Connection timeout" },
  { template: nil, command: "GetChat", success: true, response: "Chat log retrieved" },
  { template: "Broadcast", command: "Broadcast Event PvP ce soir à 21h!", success: true, response: "Message sent" },
  { template: "AddPoints", command: "AddPoints {eos_id} 300", success: true, response: "Points added successfully" },
  { template: "GiveItem", command: "GiveItemToPlayer {eos_id} PrimalItemResource_Polymer_C 200 0", success: true, response: "Item given" }
]

executions_data.each_with_index do |exec_data, i|
  template = exec_data[:template] ? created_templates.find { |t| t.name == exec_data[:template] } : nil
  player = template&.requires_player ? players.sample : nil
  admin = created_admins.sample

  full_command = exec_data[:command].gsub("{eos_id}", player&.eos_id || "unknown")

  execution = RconExecution.create!(
    user: admin,
    player: player,
    rcon_command_template: template,
    map: MAPS.sample,
    full_command: full_command,
    response: exec_data[:response],
    success: exec_data[:success],
    created_at: rand(1..48).hours.ago
  )

  puts "  - #{execution.full_command[0..40]}... (#{execution.success? ? 'OK' : 'FAIL'})"
end

puts "\nSeed complet!"
puts "  - #{Player.count} joueurs"
puts "  - #{User.count} utilisateurs"
puts "  - #{RconCommandTemplate.count} templates RCON"
puts "  - #{RconExecution.count} exécutions RCON"
