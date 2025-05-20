namespace :discord do
  desc 'Start Discord bot'
  task start: :environment do
    bot = Discordrb::Bot.new(
      token: ENV['DISCORD_BOT_TOKEN'],
      intents: [:server_messages, :message_content, :guilds] # Ajout des intents nécessaires
    )

    bot.message do |event|
      # puts "Message reçu: #{event.content}"
      # Pour tester, on fait simplement écho du message
      p event.channel.id if event.channel.id.to_s == ENV['DISCORD_CHANNEL_ID']
      p event.channel.name if event.channel.id.to_s == ENV['DISCORD_CHANNEL_ID']
      # p event.content if event.channel.id.to_s == ENV['DISCORD_CHANNEL_ID']
      # event.respond "J'ai reçu: #{event.content}" if event.channel.id.to_s == ENV['DISCORD_CHANNEL_ID']
    end

    puts 'Bot Discord démarré!'
    bot.run
  end
end