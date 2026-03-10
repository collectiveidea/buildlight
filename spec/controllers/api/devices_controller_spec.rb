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
    let!(:device) { FactoryBot.create(:device, identifier: "abc123", webhook_url: "https://localhost/fake/path") }

    it "triggers a webhook" do
      stub = stub_request(:post, "https://localhost/fake/path")
      post :trigger, params: {name: "ready", data: "true", coreid: "abc123", published_at: "2016-06-14T22:06:10.976Z"}
      expect(stub).to have_been_requested
    end

    it "does not trigger if there is no device" do
      stub = stub_request(:post, "https://localhost/fake/path")
      post :trigger, params: {name: "ready", data: "true", coreid: "FAKE", published_at: "2016-06-14T22:06:10.976Z"}
      expect(stub).not_to have_been_requested
    end
  end
end
