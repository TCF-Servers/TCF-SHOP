class AdminsController < ApplicationController
  skip_before_action :authenticate_user!, only: :index
  skip_after_action :verify_authorized, only: :index
  skip_after_action :verify_policy_scoped, only: :index

  def index
    eos_ids = User.where(role: [:admin, :superadmin])
                  .joins(:player)
                  .where.not(players: { eos_id: nil })
                  .pluck("players.eos_id")

    render plain: eos_ids.join("\n")
  end
end
