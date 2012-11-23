class WebhooksController < ApplicationController
  def create
    @status = Status.new
    @status.project_id = params[:payload][:repository][:id]
    @status.project_name = params[:payload][:repository][:name]
    @status.status = params[:payload][:status_message]
    @status.save!
    head :ok
  end
end
