class ParseCircle
  def self.call(payload)
    if payload["pull_requests"].blank?
      status = Status.find_or_initialize_by(service: "circle", username: payload["username"], project_name: payload["reponame"])
      status.payload = payload if ENV['DEBUG']
      set_colors(status, payload["status"])
      status.save!
      status.trigger
    end
  end

  # Options
  # :retried, :canceled, :infrastructure_fail, :timedout, :not_run, :running,
  # :failed, :queued, :scheduled, :not_running, :no_tests, :fixed, :success
  def self.set_colors(status, code)
    status.yellow = false
    case code
    when "running", "queued", "scheduled"
      status.yellow = true
    when "success", "fixed"
      status.red = false
    else
      status.red = true
    end
  end
end
