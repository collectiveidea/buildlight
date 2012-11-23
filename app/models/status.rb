class Status < ActiveRecord::Base
  attr_accessible :project, :status

  def status_code=(code)
    self.status = case code
      when 0
        'green'
      when 1
        'red'
      else
        'yellow'
      end
  end
end
