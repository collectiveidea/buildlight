class Status < ActiveRecord::Base
  attr_accessible :project, :status

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
end
