class API::DevicesController < API::ApplicationController
  def show
    device = Device.find(params[:id])
    render json: {colors: device.colors_as_booleans, ryg: device.ryg}
  end

  def trigger
    device = Device.find_by(identifier: params[:coreid])
    device&.trigger
    head :ok
  end
end
