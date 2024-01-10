class ParseCircle
  def self.call(payload)
    return unless payload["type"] == "workflow-completed"
    # Ignore pull requests. We can't really determine a PR build, so we ignore any branches other than main/master.
    return unless payload.dig("pipeline", "vcs", "branch").in? ["main", "master"]

    status = Status.find_or_initialize_by(service: "circle", username: payload["organization"]["name"], project_name: payload["project"]["name"])
    status.payload = payload if Rails.configuration.x.debug
    set_colors(status, payload["workflow"]["status"])
    status.save!
  end

  # Potential Statuses
  # See: https://circleci.com/docs/webhooks/#event-specifications
  # "success", "failed", "error", "canceled", "unauthorized"
  def self.set_colors(status, code)
    status.yellow = false # currently no way to set yellow on Circle
    status.red = code != "success"
  end
end
