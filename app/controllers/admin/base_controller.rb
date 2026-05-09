class Admin::BaseController < ApplicationController
  layout "admin"
  before_action :authenticate_user!, :set_online_players

  private

  def set_online_players
    @online_players_count = Player.joins(:game_session).where(game_sessions: { online: true }).count
  end
end
