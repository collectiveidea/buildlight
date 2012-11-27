class ColorsController < ApplicationController
  def index
    if params[:format] == 'ryg'
      render text: Status.colors.map {|k, v| v ? k[0].upcase : k[0].downcase }.join
    else
      render json: Status.colors
    end
  end

  def show
    ids = params[:id].split(',')
    if params[:format] == 'ryg'
      render text: Status.colors(ids).map {|k, v| v ? k[0].upcase : k[0].downcase }.join
    else
      render json: Status.colors(ids)
    end
  end
end
