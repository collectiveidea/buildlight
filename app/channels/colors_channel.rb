class ColorsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "colors:#{params[:id]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
