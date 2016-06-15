class API::DevicesController < ApplicationController
  def trigger
    if device = Device.find_by(identifier: params[:coreid])
      TriggerParticle.call(device)
    end
    head :ok
  end
end
