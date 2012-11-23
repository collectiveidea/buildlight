class WebhooksController < ApplicationController
  def create
    json = JSON.parse params[:payload]
    @status = Status.new
    # @status.project_id   = json[:repository][:id]
    # @status.project_name = json[:repository][:name]
    # @status.status       = json[:status_message]
    @status.payload = request.body.read
    @status.save!
    head :ok
  end
end
