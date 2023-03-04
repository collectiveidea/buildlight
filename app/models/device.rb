class Device < ApplicationRecord
  validates :name, presence: true
  validates :identifier, uniqueness: true, presence: false
  validates :slug, uniqueness: true, presence: false

  def statuses
    Status.where(username: usernames)
      .or(Status.where("(username || '/' || project_name) IN (?)", projects))
  end

  def status
    statuses.current_status
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

  def trigger
    TriggerWebhook.call(self) if webhook_url
    TriggerParticle.call(self) if identifier
  end
end
