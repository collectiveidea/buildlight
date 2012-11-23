class ColorsController < ApplicationController
  def index
    status = Status.order('created_at DESC').first
    render :json => {red: status.status == 'red', 
                     yellow: status.status == 'yellow',
                     green: status.status == 'green' }
  end
end
