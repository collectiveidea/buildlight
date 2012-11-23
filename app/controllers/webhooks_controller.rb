class WebhooksController < ApplicationController
  def create
    json = JSON.parse params[:payload]
    @status = Status.new
    @status.project_id   = json["repository"]["id"]
    @status.project_name = json["repository"]["name"]
    @status.status_code  = json["status"]
    @status.save!
    head :ok
  end
end
