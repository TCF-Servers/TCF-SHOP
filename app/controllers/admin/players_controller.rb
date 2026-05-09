module Admin
  class PlayersController < BaseController
    before_action :set_player, only: [:edit, :update, :destroy]

    def index
      authorize Player, :index?
      @query = params[:q].to_s.strip
      scope = policy_scope(Player).includes(:game_session)

      @players = if @query.present?
        scope.search_by_query(@query)
      else
        scope.order(in_game_name: :asc)
      end
    end

    def edit
      authorize @player
    end

    def update
      authorize @player
      if @player.update(player_params)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to admin_players_path, notice: "Joueur mis à jour" }
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @player
      @player.destroy
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_players_path, notice: "Joueur supprimé" }
      end
    end

    private

    def set_player
      @player = Player.find(params[:id])
    end

    def player_params
      params.require(:player).permit(
        :in_game_name,
        :platform_name,
        :eos_id,
        :tribe_id,
        :tribe_name,
        :discord_name,
        :discord_id,
        :votes_count
      )
    end
  end
end
