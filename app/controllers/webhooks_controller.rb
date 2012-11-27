class WebhooksController < ApplicationController
  def create
    json = JSON.parse params[:payload]
    @status = Status.find_or_initialize_by_project_id(json["repository"]["id"].to_s)
    @status.username     = json["repository"]["owner_name"]
    @status.project_name = json["repository"]["name"]
    @status.status_code  = json["status"]
    Rails.logger.warn "AUTH: #{status.username}/#{status.project_name} with: #{authentication}"
    @status.save!
    head :ok
  end
end
