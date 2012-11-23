Buildlight::Application.routes.draw do
  resources :colors, only: :index
  post '/' => 'webhooks#create'
end
