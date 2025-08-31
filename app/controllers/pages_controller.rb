class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home, :ranking ]

  def home
  end

  def ranking
    # Current month ranking - get all players with valid votes this month
    @current_month_ranking = Player.joins(:valid_votes)
                                  .where(votes: { created_at: (Time.current.beginning_of_month - 2.hours)..(Time.current.end_of_month - 2.hours) })
                                  .distinct
                                  .sort_by(&:current_month_valid_votes)
                                  .reverse
                                  .first(50)

    # Last month ranking - get all players with valid votes last month
    @last_month_ranking = Player.joins(:valid_votes)
                               .where(votes: { created_at: (Time.current.last_month.beginning_of_month - 2.hours)..(Time.current.last_month.end_of_month - 2.hours) })
                               .distinct
                               .sort_by(&:last_month_valid_votes)
                               .reverse
                               .first(50)
  end
end
