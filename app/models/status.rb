class Status < ActiveRecord::Base
  attr_accessible :project, :status

  scope :recent, order('created_at DESC')

  # Set color based on travis-ci's status code
  def status_code=(code)
    self.color = case code
      when 0
        'green'
      when 1
        'red'
      else
        'yellow'
      end
  end

  def self.colors
    yellow = green = false
    color = recent.first.try(:color)
    if color == 'yellow'
      yellow = true
      green = recent.where("color != 'yellow'").first.try(:color) == 'green'
    elsif color == 'green'
      green = true
    end
    
    {red: !green, yellow: yellow, green: green }
  end
end
