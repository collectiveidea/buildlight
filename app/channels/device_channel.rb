class DeviceChannel < ApplicationCable::Channel
  after_subscribe :initial_broadcast

  def subscribed
    @slug = params[:id]

    # Uses friend device slug rather than id.
    # device:my-slug
    stream_from "device:#{@slug}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def initial_broadcast
    # Trigger an initial broadcast.
    Device.find_by(slug: @slug)&.broadcast
  end
end
