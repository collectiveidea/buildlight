class ColorsController < ApplicationController
  def index
    render :json => Status.colors
  end
end
