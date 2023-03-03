class Status < ApplicationRecord
  def name
    "#{username}/#{project_name}"
  end

  # Devices that are "watching" this Status
  def devices
    Device.where("usernames @> ARRAY[?]::varchar[]", [username])
      .or(Device.where("projects @> ARRAY[?]::varchar[]", [name]))
  end

  def self.colors(username = nil)
    user_scope = username.present? ? where(username: username) : all
    red = user_scope.where(red: true).count
    red = false if red.zero?
    yellow = user_scope.where(yellow: true).any?

    {red: red, yellow: yellow, green: !red}
  end

  def self.ryg(username = nil)
    Status.colors(username).map { |k, v| v ? k[0].upcase : k[0].downcase }.join
  end

  def self.current_status
    red = "failing" if where(red: true).any?
    yellow = "building" if where(yellow: true).any?
    green = "passing" unless red
    [green, red, yellow].compact.join("-") # combines status to send "passing|failing-building"
  end

  # Trigger updates to devices and channels
  def trigger
    ColorsChannel.broadcast_to("*", colors: Status.colors)
    ColorsChannel.broadcast_to(username, colors: Status.colors(username))
    devices.each(&:trigger)
  end
end
