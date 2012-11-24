class ColorsController < ApplicationController
  def index
    render json: Status.colors
  end

  def show
    render json: Status.colors(params[:id].split(','))
  end
end
