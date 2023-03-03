require "rails_helper"

describe TriggerWebhook do
  describe "triggering a webhook" do
    let(:device) { FactoryBot.create(:device, usernames: ["hooks"], webhook_url: "https://localhost/fake/path") }
    let(:status) { FactoryBot.create(:status, username: "hooks", project_name: "buildlight") }

    it "it sends a basic webhook" do
      allow(Faraday).to receive(:post)
      TriggerWebhook.call(device)
      expect(Faraday).to have_received(:post).with(
        "https://localhost/fake/path",
        {colors: {red: false, yellow: false, green: true}}.to_json,
        {"Content-Type": "application/json", "x-ryg": "ryG", "x-device-url": "http://locahost:3000/api/devices/#{device.id}"}
      )
    end
  end
end
