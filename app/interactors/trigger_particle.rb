class TriggerParticle
  def self.call(status)
    Particle.publish(name: "build_state", data: status, ttl: 3600, private: false)
  end
end
