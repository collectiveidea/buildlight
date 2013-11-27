class RedController < ApplicationController
  def index
    @red_projects = Status.where(red: true)
    respond_to do |format|
      format.html
      format.json { render json: @red_projects }
    end
  end

  def show
    usernames = params[:id].split(',')
    @red_projects = Status.where(red: true, username: usernames)
    respond_to do |format|
      format.html { render :index }
      format.json { render json: @red_projects }
    end
  end
end
