require 'digest'
class WebhooksController < ApplicationController
  def create
    json = JSON.parse params[:payload]
    if json['type'] != 'pull_request'
      @status = Status.find_or_initialize_by(:project_id => json["repository"]["id"].to_s)
      @status.payload = params[:payload] if ENV['DEBUG']
      @status.username     = json["repository"]["owner_name"]
      @status.project_name = json["repository"]["name"]
      @status.status_code  = json["status_message"]
      Rails.logger.warn "AUTH: #{@status.name} with: #{request.headers['Authorization']}"
      @status.save!
      TriggerParticle.call(Status.current_status)
    end
    head :ok
  end
end
