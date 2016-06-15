class TriggerParticle
  def self.call(device)
    Particle.publish(name: "build_state", data: device.status, ttl: 3600, private: false)
  end
end
