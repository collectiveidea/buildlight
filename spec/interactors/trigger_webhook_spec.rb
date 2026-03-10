require "rails_helper"

describe TriggerWebhook do
  describe "triggering a webhook" do
    let!(:status) { FactoryBot.create(:status, username: "hooks", project_name: "buildlight") }
    let!(:device) { FactoryBot.create(:device, usernames: ["hooks"]) }

    it "it sends a basic webhook" do
      # Add webhook without triggering callbacks
      device.update_column(:webhook_url, "https://localhost/fake/path")

      stub = stub_request(:post, "https://localhost/fake/path")
        .with(
          body: {colors: {red: false, yellow: false, green: true}}.to_json,
          headers: {"Content-Type": "application/json", "x-ryg": "ryG", "x-device-url": "http://locahost:3000/api/devices/#{device.id}"}
        )
      TriggerWebhook.call(device)
      expect(stub).to have_been_requested
    end
  end
end
