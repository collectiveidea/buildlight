require 'digest'
class WebhooksController < ApplicationController
  def create
    if params[:payload].is_a?(String)
      ParseTravis.call(params[:payload])
    else
      ParseCircle.call(params[:payload])
    end

    head :ok
  end
end
