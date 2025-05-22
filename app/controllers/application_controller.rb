class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, only: [:healthcheck]

  # Méthode pour le healthcheck (pour UptimeRobot)
  def healthcheck
    # Vérifier si le worker du bot Discord est en cours d'exécution
    # Cette vérification est simplifiée car nous n'avons pas accès direct au worker depuis le web dyno
    # Mais nous pouvons au moins répondre avec un statut 200 pour UptimeRobot
    render plain: "OK", status: 200
  end
end