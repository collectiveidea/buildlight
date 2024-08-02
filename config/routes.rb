Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # use a namespace to avoid resources colliding with usernames
  namespace :api do
    resources :devices, only: :show
    resource :device, only: [] do
      post :trigger
      get ":id/red" => "red#show"
    end
  end

  resources :devices, only: :show
  get ":id(.:format)" => "colors#show"
  get "/(.:format)" => "colors#index"
  post "/" => "webhooks#create"
end
