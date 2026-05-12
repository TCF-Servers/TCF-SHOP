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
        outcome = broadcast_rcon!("BanPlayer #{@banned_player.eos_id}", player: @banned_player.player)
        flash_message ban_message(@banned_player.eos_id, outcome), outcome
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
      eos_id = @banned_player.eos_id
      player = @banned_player.player
      @banned_player.destroy

      outcome = broadcast_rcon!("UnbanPlayer #{eos_id}", player: player)
      flash_message unban_message(eos_id, outcome), outcome
    end

    private

    # Diffuse une commande RCON sur toutes les maps du cluster et journalise un
    # RconExecution agrégé. Renvoie :rcon_ok, :rcon_partial ou :rcon_failed.
    def broadcast_rcon!(command, player: nil)
      results = RconDispatcher.execute_and_log_all(command, user: current_user, player: player)
      ok = results.values.count(&:success?)
      return :rcon_failed if results.empty? || ok.zero?

      ok == results.size ? :rcon_ok : :rcon_partial
    rescue StandardError => e
      Rails.logger.error("[RCON] échec lors de la diffusion de '#{command}': #{e.class}: #{e.message}")
      :rcon_failed
    end

    def flash_message(message, outcome)
      key = outcome == :rcon_ok ? :notice : :alert
      respond_to do |format|
        format.turbo_stream { flash.now[key] = message }
        format.html { redirect_to admin_banned_players_path, flash: { key => message } }
      end
    end

    def ban_message(eos_id, outcome)
      rcon_outcome_message("EOS ID #{eos_id} ajouté à la banlist.", "BanPlayer", outcome)
    end

    def unban_message(eos_id, outcome)
      rcon_outcome_message("Bannissement de #{eos_id} levé.", "UnbanPlayer", outcome)
    end

    def rcon_outcome_message(base, rcon_verb, outcome)
      case outcome
      when :rcon_ok
        "#{base} #{rcon_verb} envoyé sur toutes les maps."
      when :rcon_partial
        "#{base} ⚠️ #{rcon_verb} envoyé, mais certaines maps n'ont pas répondu — voir le journal RCON."
      else
        "#{base} ⚠️ La commande RCON #{rcon_verb} a échoué — aucun serveur n'a répondu."
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
