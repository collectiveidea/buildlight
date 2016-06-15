require 'rails_helper'

describe API::DevicesController do
  describe 'POST trigger' do
    before do
      allow(Particle).to receive(:publish)
    end

    it 'notifies Particle' do
      expect(Particle).to receive(:publish).with({name: "build_state", data: "passing", ttl: 3600, private: false})
      post :trigger, device_id: "abc123", name: "ready", data: "true", coreid: "abc123", published_at: "2016-06-14T22:06:10.976Z"
    end
  end
end
