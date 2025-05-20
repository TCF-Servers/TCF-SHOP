# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

require 'rcon'
require 'timeout'

begin
  Timeout::timeout(50) do 
    puts "Tentative de connexion au serveur..."
    client = Rcon::Client.new(host: '213.133.103.176', port: 59202, password: 'GaI2c2mwR17JP4DNd71vHZWHLjP37tizsnwu8Ip98Lc1IM7yxh')
    puts "Tentative d'authentification..."
    p client
    client.authenticate!(ignore_first_packet: false)
    puts "Authentification réussie!"
    
    response = client.execute('Listplayers')
    p response
    
    client.close
    puts "Connexion fermée"
  end
rescue Timeout::Error
  puts "Timeout - L'authentification a pris trop de temps"
rescue => e
  puts "Erreur : #{e.class} - #{e.message}"
ensure
  client&.close if defined?(client)
end