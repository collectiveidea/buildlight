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

  def self.colors
    red    = where(red: true).any?
    yellow = where(yellow: true).any?

    {red: red, yellow: yellow, green: !red }
  end
end
