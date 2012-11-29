class ColorsController < ApplicationController
  include ActionController::Live

  def index
    respond_to do |format|
      format.ryg do
        begin
          response.headers['Content-Type'] = 'text/ryg'
          loop do
            response.stream.write Status.uncached { Status.ryg(@ids) }
            sleep 1
          end
        rescue IOError
          response.stream.close
        end
      end
      format.any { render json: Status.colors(@ids) }
    end
  end

  def show
    @ids = params[:id].split(',')
    index
  end
end
