require "digest"
class WebhooksController < API::ApplicationController
  def create
    if params[:payload].is_a?(String)
      ParseTravis.call(params[:payload])
    elsif params[:payload].blank?
      ParseGithub.call(params)
    else
      ParseCircle.call(params[:payload])
    end

    head :ok
  end
end
