class ColorsController < ApplicationController
  def index
    if params[:format] == 'ryg'
      render text: Status.ryg
    else
      render json: Status.colors
    end
  end

  def show
    ids = params[:id].split(',')
    if params[:format] == 'ryg'
      render text: Status.ryg(ids)
    else
      render json: Status.colors(ids)
    end
  end
end
