require "digest"
class WebhooksController < API::ApplicationController
  def create
    if params[:payload].is_a?(String)
      ParseTravis.call(params[:payload])
      head :ok
    elsif params[:payload].blank? && params[:repository]&.include?("/")
      ParseGithub.call(params)
      head :ok
    elsif request.headers.env["HTTP_CIRCLECI_EVENT_TYPE"].present?
      ParseCircle.call(params)
      head :ok
    else
      head :bad_request
    end
  end
end
