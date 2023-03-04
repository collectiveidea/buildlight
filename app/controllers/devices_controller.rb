class DevicesController < ApplicationController
  def show
    device = Device.where(slug: params[:id]).or(Device.where(id: params[:id])).sole

    respond_to do |format|
      format.html do
        @colors = device.colors
        render "colors/index"
      end
      format.json { render json: device.colors }
    end
  end
end
