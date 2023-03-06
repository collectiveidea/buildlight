class DeviceChannel < ApplicationCable::Channel
  def subscribed
    # Uses friend device slug rather than id.
    # device:my-slug
    stream_from "device:#{params[:id]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
