class ColorsController < ApplicationController
  def index
    yellow = green = false
    status = Status.order('created_at DESC').first
    if status.color == 'yellow'
      yellow = true
      previous = Status.order('created_at DESC').where("color != 'yellow'").first
    end

    if status.color == 'green' || (previous && previous.color == 'green')
      green = true
    end

    render :json => {red: !green,
                     yellow: yellow,
                     green: green }
  end
end
