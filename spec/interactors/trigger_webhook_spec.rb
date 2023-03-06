require "rails_helper"

describe TriggerWebhook do
  describe "triggering a webhook" do
    let!(:status) { FactoryBot.create(:status, username: "hooks", project_name: "buildlight") }
    let!(:device) { FactoryBot.create(:device, usernames: ["hooks"]) }

    it "it sends a basic webhook" do
      # Add webhook without triggering callbacks
      device.update_column(:webhook_url, "https://localhost/fake/path")

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
