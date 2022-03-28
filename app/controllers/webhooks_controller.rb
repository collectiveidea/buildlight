require "digest"
class WebhooksController < API::ApplicationController
  def create
    if params[:payload].is_a?(String)
      ParseTravis.call(params[:payload])
      head :ok && return
    elsif params[:payload].blank? && params[:repository]&.include?("/")
      ParseGithub.call(params)
      head :ok && return
    elsif params[:payload]
      ParseCircle.call(params[:payload])
      head :ok && return
    end

    head :bad_request
  end
end
