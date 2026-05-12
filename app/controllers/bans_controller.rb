class BansController < ApplicationController
  skip_before_action :authenticate_user!, only: :index
  skip_after_action :verify_authorized, only: :index
  skip_after_action :verify_policy_scoped, only: :index

  # Liste des EOS IDs bannis encore actifs (consommée par le serveur de jeu),
  # sur le même modèle que /admins.txt
  def index
    eos_ids = BannedPlayer.active.order(:created_at).pluck(:eos_id)

    render plain: eos_ids.join("\n")
  end
end
