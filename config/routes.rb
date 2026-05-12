Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  # Route pour le healthcheck (pour UptimeRobot)
  get '/healthcheck', to: 'application#healthcheck'

  # Liste des EOS IDs des administrateurs (consommée par le serveur de jeu)
  get '/admins.txt', to: 'admins#index'

  # Liste des EOS IDs bannis encore actifs (consommée par le serveur de jeu)
  get '/bans.txt', to: 'bans#index'

  get :ranking, to: 'pages#ranking'
  namespace :admin do
    get :dashboard, to: 'dashboard#index'
    resources :rcon_command_templates
    resources :players, only: [:index, :edit, :update, :destroy]
    resources :banned_players, only: [:index, :create, :destroy]
  end
end
