Buildlight::Application.routes.draw do
  resources :webhooks, :only => :create
end
