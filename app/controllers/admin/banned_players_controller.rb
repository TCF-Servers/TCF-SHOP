module Admin
  class BannedPlayersController < BaseController
    before_action :set_banned_player, only: :destroy

    def index
      authorize BannedPlayer, :index?
      @banned_players = policy_scope(BannedPlayer).includes(:player, :banned_by).recent
      @banned_player = BannedPlayer.new
    end

    def create
      @banned_player = BannedPlayer.new(banned_player_params)
      @banned_player.banned_by = current_user
      authorize @banned_player

      if @banned_player.save
        outcome = enforce_ban!(@banned_player)
        message = ban_message(@banned_player, outcome)
        flash_key = outcome == :rcon_failed ? :alert : :notice

        respond_to do |format|
          format.turbo_stream { flash.now[flash_key] = message }
          format.html { redirect_to admin_banned_players_path, flash: { flash_key => message } }
        end
      else
        respond_to do |format|
          format.turbo_stream { render :create, status: :unprocessable_entity }
          format.html do
            @banned_players = policy_scope(BannedPlayer).includes(:player, :banned_by).recent
            render :index, status: :unprocessable_entity
          end
        end
      end
    end

    def destroy
      authorize @banned_player
      @banned_player.destroy
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_banned_players_path, notice: "Bannissement levé" }
      end
    end

    private

    # Si le joueur est en base et connecté, on l'expulse du serveur via RCON
    # (BanPlayer <eos_id>) et on journalise un RconExecution.
    # Renvoie :offline, :rcon_sent ou :rcon_failed.
    def enforce_ban!(banned_player)
      player = banned_player.player
      return :offline unless player&.online?

      execution = RconDispatcher.execute_and_log(
        "BanPlayer #{banned_player.eos_id}",
        map_name: player.current_map,
        user: current_user,
        player: player
      )
      execution.success? ? :rcon_sent : :rcon_failed
    rescue StandardError => e
      Rails.logger.error("[BanPlayer] échec lors de l'expulsion RCON de #{banned_player.eos_id}: #{e.class}: #{e.message}")
      :rcon_failed
    end

    def ban_message(banned_player, outcome)
      base = "EOS ID #{banned_player.eos_id} ajouté à la banlist."
      case outcome
      when :rcon_sent
        map = banned_player.player.game_session&.formatted_map_name || banned_player.player.current_map
        "#{base} Joueur expulsé du serveur (#{map}) via RCON."
      when :rcon_failed
        "#{base} ⚠️ La commande RCON BanPlayer a échoué — expulse le joueur manuellement."
      else
        "#{base} Le joueur n'est pas connecté : aucune commande RCON envoyée."
      end
    end

    def set_banned_player
      @banned_player = BannedPlayer.find(params[:id])
    end

    def banned_player_params
      params.require(:banned_player).permit(:eos_id, :reason, :expires_at)
    end
  end
end
