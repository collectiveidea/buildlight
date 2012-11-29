class ColorsController < ApplicationController
  include ActionController::Live

  def index
    if params[:format] == 'ryg'
      begin
        response.headers['Content-Type'] = 'text/ryg'
        loop do
          response.stream.write Status.uncached { Status.ryg(@ids) }
          sleep 1
        end
      rescue IOError
        response.stream.close
      end
    else
      render json: Status.colors(@ids)
    end    
  end

  def show
    @ids = params[:id].split(',')
    index
  end
end
