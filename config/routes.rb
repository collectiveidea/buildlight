Buildlight::Application.routes.draw do
  resources :webhooks, :only => :create
  post '/' => 'webhooks#create'
end
