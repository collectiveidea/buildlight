Buildlight::Application.routes.draw do
  get ':id' => 'colors#show'
  get '/' => 'colors#index'
  post '/' => 'webhooks#create'
end
