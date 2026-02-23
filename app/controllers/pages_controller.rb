class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home, :ranking ]

  def home
    redirect_to ranking_path
  end

  def ranking
    # Current month ranking
    @current_month_ranking = Player.joins(:valid_votes)
                                  .where(votes: { created_at: Time.current.all_month })
                                  .group("players.id")
                                  .order("COUNT(votes.id) DESC")
                                  .limit(50)

    # Last month ranking
    last_month = Time.current.last_month
    @last_month_ranking = Player.joins(:valid_votes)
                               .where(votes: { created_at: last_month.all_month })
                               .group("players.id")
                               .order("COUNT(votes.id) DESC")
                               .limit(50)
  end
end
