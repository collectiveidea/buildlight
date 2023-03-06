class Device < ApplicationRecord
  validates :name, presence: true
  validates :identifier, uniqueness: {allow_blank: true}
  validates :slug, uniqueness: {allow_blank: true}

  # Ensure the status is updated if we change anything
  after_commit :update_status, on: [:create, :update]

  def statuses
    Status.where(username: usernames)
      .or(Status.where("(username || '/' || project_name) IN (?)", projects))
  end

  def colors
    statuses.colors
  end

  def colors_as_booleans
    statuses.colors_as_booleans
  end

  def ryg
    statuses.ryg
  end

  def update_status
    self.status = statuses.current_status
    DeviceChannel.broadcast_to(slug, colors: colors) if slug

    if status_changed?
      self.status_changed_at = Time.current
      save!
      # Currenly only triggering on status change to reduce webhooks
      trigger
    end
  end

  def trigger
    TriggerWebhook.call(self) if webhook_url
    TriggerParticle.call(self) if identifier
  end
end
