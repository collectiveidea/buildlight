class ParseTravis
  def self.call(payload)
    json = JSON.parse(payload)
    if json['type'] != 'pull_request'
      status = Status.find_or_initialize_by(service: "travis", project_id: json["repository"]["id"].to_s)
      status.payload = payload if ENV['DEBUG']
      status.username     = json["repository"]["owner_name"]
      status.project_name = json["repository"]["name"]
      set_colors(status, json["status_message"])
      status.save!
      status.devices.each do |device|
        TriggerParticle.call(device)
      end
    end
  end

  # Set colors based on travis-ci's status code
  def self.set_colors(status, code)
    status.yellow = false
    case code
    when "Pending"
      status.yellow = true
    when "Passed", "Fixed"
      status.red = false
    else
      status.red = true
    end
  end
end
