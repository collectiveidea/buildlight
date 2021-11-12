class API::DevicesController < API::ApplicationController
  def trigger
    device = Device.find_by(identifier: params[:coreid])
    if device
      TriggerParticle.call(device)
    end
    head :ok
  end
end
