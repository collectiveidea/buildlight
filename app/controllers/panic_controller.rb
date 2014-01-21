class PanicController < ApplicationController
  include ActionController::Live

  def index
    respond_to do |format|
      format.html do
        @colors = Status.colors(@ids)
        render 'index'
      end
      format.json { render json: Status.colors(@ids) }
    end
  end
end
