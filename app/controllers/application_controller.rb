class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, only: [:healthcheck]
  include Pundit::Authorization

  after_action :verify_authorized, except: [:index, :healthcheck], unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?
  
  # Méthode pour le healthcheck (pour UptimeRobot)
  def healthcheck
    # Vérifier si le worker du bot Discord est en cours d'exécution
    # Cette vérification est simplifiée car nous n'avons pas accès direct au worker depuis le web dyno
    # Mais nous pouvons au moins répondre avec un statut 200 pour UptimeRobot
    render plain: "OK", status: 200
  end


  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def user_not_authorized
    flash[:alert] = "Vous n'êtes pas autorisé à accéder à cette page."
    redirect_to(root_path)
  end

  private

  def skip_pundit?
    devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
  end
end
