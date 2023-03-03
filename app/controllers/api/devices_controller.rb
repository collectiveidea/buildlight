class API::DevicesController < API::ApplicationController
  def show
    device = Device.find(params[:id])
    render json: {colors: device.colors, ryg: device.ryg}
  end

  def trigger
    device = Device.find_by(identifier: params[:coreid])
    if device
      TriggerParticle.call(device)
    end
    head :ok
  end
end
