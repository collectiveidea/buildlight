class ColorsController < ApplicationController
  include ActionController::Live

  def index
    respond_to do |format|
      format.html do
        @colors = Status.colors(@ids)
        render "index"
      end
      format.ryg do
        begin
          response.headers["Content-Type"] = "text/ryg"

          ActiveRecord::Base.connection_pool.release_connection

          loop do
            ActiveRecord::Base.connection_pool.with_connection do
              response.stream.write Status.uncached { Status.ryg(@ids) }
            end

            sleep 1
          end
        rescue IOError
          response.stream.close
        end
      end
      format.json { render json: Status.colors(@ids) }
    end
  end

  def show
    @ids = params[:id].split(",")
    index
  end
end
