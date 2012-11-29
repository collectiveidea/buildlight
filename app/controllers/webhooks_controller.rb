require 'digest'
class WebhooksController < ApplicationController
  def create
    json = JSON.parse params[:payload]
    @status = Status.find_or_initialize_by_project_id(json["repository"]["id"].to_s)
    @status.username     = json["repository"]["owner_name"]
    @status.project_name = json["repository"]["name"]
    @status.status_code  = json["status"]
    Rails.logger.warn "AUTH: #{@status.username}/#{@status.project_name} with: #{request.headers['Authorization']}"
    @status.save!
    Status.notify
    head :ok
  end

  private
  def authorize(status, authentication)
    string = "#{status.username}/#{status.project_name}#{User.find_or_create_by_username(status.username).travis_token}"
    if Digest::SHA256.new.hexdigest(string) == authentication
      true
    else
      Rails.logger.warn "AUTH FAILURE: #{status.username}/#{status.project_name} with: #{authentication}"
      true
    end
  end
end
