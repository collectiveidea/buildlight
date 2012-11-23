class WebhooksController < ApplicationController
  def create
    @status = Status.new
    @status.project_id = params[:id]
    @status.project_name = params[:repository][:name]
    @status.status = params[:status_message]
    @status.save!
    head :ok
  end
end
