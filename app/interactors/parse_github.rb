class ParseGithub
  def self.call(payload)
    username, project_name = payload["repository"].split("/")
    workflow = payload["workflow"]
    status = Status.find_or_initialize_by(service: "github", username: username, project_name: project_name, workflow: workflow)
    status.payload = payload if Rails.configuration.x.debug
    set_colors(status, payload["status"])
    status.save!
  end

  # Options
  # "success", "failure", ""
  def self.set_colors(status, code)
    status.yellow = false
    case code
    when ""
      status.yellow = true
    when "success"
      status.red = false
    when "failure"
      status.red = true
    else
      raise "Unknown status: #{code}"
    end
  end
end
