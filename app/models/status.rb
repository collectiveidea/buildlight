class Status < ApplicationRecord
  def name
    "#{username}/#{project_name}"
  end

  # Devices that are "watching" this Status
  def devices
    Device.where("usernames @> ARRAY[?]::varchar[]", [username]).
      or(Device.where("projects @> ARRAY[?]::varchar[]", [name]))
  end

  def self.colors(username = nil)
    user_scope = username.present? ? where(username: username) : all
    red    = user_scope.where(red: true).any?
    yellow = user_scope.where(yellow: true).any?

    {red: red, yellow: yellow, green: !red }
  end

  def self.ryg(username = nil)
    Status.colors(username).map {|k, v| v ? k[0].upcase : k[0].downcase }.join
  end

  def self.current_status
    red    = "failing" if where(red: true).any?
    yellow = "building" if where(yellow: true).any?
    green = "passing" if !red
    [green, red, yellow].compact.join("-") # combines status to send "passing|failing-building"
  end
end
