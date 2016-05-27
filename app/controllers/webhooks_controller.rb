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
      Particle.publish(name: "build_state", data: Status.current_status, ttl: 3600, private: false)
    end
    head :ok
  end

  private
  def authorize(status, authentication)
    string = "#{status.name}#{User.find_or_create_by_username(status.username).travis_token}"
    if Digest::SHA256.new.hexdigest(string) == authentication
      true
    else
      Rails.logger.warn "AUTH FAILURE: #{status.name} with: #{authentication}"
      true
    end
  end
end
