require "rails_helper"

describe API::DevicesController do
  describe "GET show" do
    it "returns the colors" do
      device = FactoryBot.create(:device, usernames: ["test"])
      FactoryBot.create(:status, username: "test", red: false, yellow: true)

      get :show, params: {id: device.id}
      expect(response.status).to eq(200)
      expect(response.body).to eq({colors: {red: false, yellow: true, green: true}, ryg: "rYG"}.to_json)
    end
  end

  describe "POST trigger" do
    before do
      FactoryBot.create(:device, identifier: "abc123")
      allow(Particle).to receive(:publish)
    end

    it "notifies Particle" do
      expect(Particle).to receive(:publish).with(name: "build_state", data: "passing", ttl: 3600, private: false)
      post :trigger, params: {name: "ready", data: "true", coreid: "abc123", published_at: "2016-06-14T22:06:10.976Z"}
    end

    it "does not notify if there is no device" do
      expect(Particle).not_to receive(:publish)
      post :trigger, params: {name: "ready", data: "true", coreid: "FAKE", published_at: "2016-06-14T22:06:10.976Z"}
    end
  end
end
