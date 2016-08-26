Rails.application.routes.draw do
  get '/.well-known/acme-challenge/:id' => 'pages#letsencrypt'

  # use a namespace to avoid resources colliding with usernames
  namespace :api do
    resource :device, only: [] do
      post :trigger
      get ':id/red' => 'red#show'
    end
  end

  get ':id(.:format)' => 'colors#show'
  get '/(.:format)' => 'colors#index'
  post '/' => 'webhooks#create'
end
