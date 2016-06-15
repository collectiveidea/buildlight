class API::DevicesController < ApplicationController
  def trigger
    TriggerParticle.call(Status.current_status)
    head :ok
  end
end
