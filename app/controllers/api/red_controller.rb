class API::RedController < ApplicationController
  def show
    device = Device.find_sole_by(identifier: params[:id])
    @red_projects = device.statuses.where(red: true)
    respond_to do |format|
      format.html
      format.json { render json: @red_projects.to_json(only: [:username, :project_name]) }
    end
  end
end
