Buildlight::Application.routes.draw do
  get ':id(.:format)' => 'colors#show'
  get '/(.:format)' => 'colors#index'
  post '/' => 'webhooks#create'
end
