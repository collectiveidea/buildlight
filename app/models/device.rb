class Device < ApplicationRecord
  validates :name, presence: true
  validates :identifier, uniqueness: true, presence: true

  def statuses
    Status.where(username: usernames)
      .or(Status.where("(username || '/' || project_name) IN (?)", projects))
  end

  def status
    statuses.current_status
  end
end
