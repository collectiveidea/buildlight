class ParseCircle
  def self.call(payload)
    return unless payload["type"] == "workflow-completed"

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
