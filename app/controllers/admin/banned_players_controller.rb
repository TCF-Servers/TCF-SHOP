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
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to admin_banned_players_path, notice: "EOS ID #{@banned_player.eos_id} ajouté à la banlist" }
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

    def set_banned_player
      @banned_player = BannedPlayer.find(params[:id])
    end

    def banned_player_params
      params.require(:banned_player).permit(:eos_id, :reason, :expires_at)
    end
  end
end
