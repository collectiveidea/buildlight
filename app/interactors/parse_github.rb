class ParseGithub
  # Conclusions GitHub can report for a workflow_run.
  # See: https://docs.github.com/en/webhooks/webhook-events-and-payloads#workflow_run
  BUILDING = ["", nil].freeze
  GREEN = ["success"].freeze
  RED = ["failure", "timed_out", "startup_failure"].freeze
  # The run ended without telling us anything about the health of the branch.
  INCONCLUSIVE = ["cancelled", "skipped", "neutral", "stale", "action_required"].freeze

  def self.call(payload)
    username, project_name = payload["repository"].split("/")
    workflow = payload["workflow"]
    status = Status.find_or_initialize_by(service: "github", username: username, project_name: project_name, workflow: workflow)
    status.payload = payload if Rails.configuration.x.debug
    set_colors(status, payload["status"])
    status.save!
  end

  # Building is always cleared: every conclusion means the run is over, except the
  # empty one GitHub sends while it is still in progress.
  # Red is only touched by conclusions that say something about the branch. A
  # cancelled or skipped run leaves the last known result in place, otherwise a
  # stray cancel would wedge a project in "building" (or clear a real failure).
  def self.set_colors(status, code)
    status.yellow = false
    if BUILDING.include?(code)
      status.yellow = true
    elsif GREEN.include?(code)
      status.red = false
    elsif RED.include?(code)
      status.red = true
    elsif !INCONCLUSIVE.include?(code)
      Rails.logger.warn("ParseGithub: unknown conclusion #{code.inspect}, treating as inconclusive")
    end
  end
end
