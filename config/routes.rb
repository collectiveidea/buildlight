Buildlight::Application.routes.draw do
  post '/' => 'webhooks#create'
end
