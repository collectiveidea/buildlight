class API::DevicesController < ApplicationController
  def trigger
    Particle.publish(name: "build_state", data: Status.current_status, ttl: 3600, private: false)
    head :ok
  end
end
