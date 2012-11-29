class Status < ActiveRecord::Base
  attr_accessible :project, :status

  # Set colors based on travis-ci's status code
  def status_code=(code)
    self.yellow = false
    case code
      when 0
        self.red = false
      when 1
        self.red = true
      else
        self.yellow = true
      end
  end

  def self.colors(username = nil)
    user_scope = username.present? ? where(username: username) : scoped
    red    = user_scope.where(red: true).any?
    yellow = user_scope.where(yellow: true).any?

    {red: red, yellow: yellow, green: !red }
  end

  def self.ryg(username = nil)
    Status.colors(username).map {|k, v| v ? k[0].upcase : k[0].downcase }.join
  end

  def self.notify
    MQTT::Client.connect 'test.mosquitto.org' do |c|
      c.publish 'collectiveidea/buildlight', Status.ryg
    end
  end
end
