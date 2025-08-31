# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts " Seeding database..."

# Use existing players from database
puts "Loading existing players..."
players = Player.all.to_a

if players.empty?
  puts " No players found in database. Please create some players first."
  exit
end

puts "Found #{players.count} existing players:"
players.each { |p| puts "  #{p.in_game_name}" }

# Generate random votes from last month
puts "\nGenerating random votes from last month..."

last_month_start = Time.current.last_month.beginning_of_month - 2.hours
last_month_end = Time.current.last_month.end_of_month - 2.hours

# Create 100 random votes distributed among existing players
100.times do |i|
  # Select random player from existing players
  player = players.sample
  
  # Random date within last month
  random_date = rand(last_month_start..last_month_end)
  
  # Create vote
  Vote.create!(
    player: player,
    source: "topserveur",
    points_awarded: 150,
    processed: true,
    vote_valid: true,
    created_at: random_date,
    updated_at: random_date
  )
  
  # Update player's votes_count
  player.increment!(:votes_count)
  
  print "." if (i + 1) % 10 == 0
end

puts "\n\n Seed data created successfully!"
puts "Players used: #{players.count}"
puts "Votes created: 100 (from last month)"
puts "Date range: #{last_month_start.strftime('%d/%m/%Y')} - #{last_month_end.strftime('%d/%m/%Y')}"

# Display top 10 ranking
puts "\n Top 10 Last Month Ranking:"
top_players = players.sort_by(&:last_month_valid_votes).reverse.first(10)
top_players.each_with_index do |player, index|
  puts "  #{index + 1}. #{player.in_game_name}: #{player.last_month_valid_votes} votes"
end

