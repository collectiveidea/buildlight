Buildlight::Application.routes.draw do
  get '/' => 'colors#index'
  post '/' => 'webhooks#create'
end
