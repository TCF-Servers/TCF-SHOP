class DashboardController < ApplicationController
  layout "admin"

  def index
    @online_players_count = Player.joins(:game_session).where(game_sessions: { online: true }).count
    @online_players = Player.joins(:game_session).where(game_sessions: { online: true }).limit(10)
    @today_votes_count = Vote.where(created_at: Time.current.beginning_of_day..).count
    @today_commands_count = RconExecution.where(created_at: Time.current.beginning_of_day..).count
    @total_players_count = Player.count
    @recent_executions = RconExecution.includes(:player, :user, :rcon_command_template)
                                       .order(created_at: :desc)
                                       .limit(10)
  end
end
