require "rails_helper"

RSpec.describe Device, type: :model do
  describe "#statuses" do
    let!(:status1) { FactoryBot.create(:status, username: "collectiveidea", project_name: "foo") }
    let!(:status2) { FactoryBot.create(:status, username: "collectiveidea", project_name: "bar") }
    let!(:status3) { FactoryBot.create(:status, username: "deadmanssnitch", project_name: "foo") }
    let!(:status4) { FactoryBot.create(:status, username: "deadmanssnitch", project_name: "bar") }
    let!(:status5) { FactoryBot.create(:status, username: "inchworm", project_name: "foo") }

    it "includes status by project" do
      device = FactoryBot.create(:device, usernames: [], projects: ["collectiveidea/bar", "deadmanssnitch/foo"])

      expect(device.statuses.size).to eq(2)
      expect(device.statuses).to include(status2)
      expect(device.statuses).to include(status3)
    end

    it "includes status by username" do
      device = FactoryBot.create(:device, usernames: ["collectiveidea", "inchworm"], projects: [])

      expect(device.statuses.size).to eq(3)
      expect(device.statuses).to include(status1)
      expect(device.statuses).to include(status2)
      expect(device.statuses).to include(status5)
    end

    it "includes status by username and project at the same time" do
      device = FactoryBot.create(:device, usernames: ["collectiveidea"], projects: ["deadmanssnitch/bar"])

      expect(device.statuses.size).to eq(3)
      expect(device.statuses).to include(status1)
      expect(device.statuses).to include(status2)
      expect(device.statuses).to include(status4)
    end
  end

  describe "#status" do
    it "returns the status for the device" do
      FactoryBot.create(:status, username: "collectiveidea", project_name: "foo", red: false, yellow: false)
      FactoryBot.create(:status, username: "collectiveidea", project_name: "bar", red: false, yellow: true)
      FactoryBot.create(:status, username: "deadmanssnitch", project_name: "foo", red: false, yellow: false)
      FactoryBot.create(:status, username: "deadmanssnitch", project_name: "bar", red: true, yellow: true)

      device = FactoryBot.create(:device, usernames: ["collectiveidea"], projects: ["deadmanssnitch/foo"])
      expect(device.status).to eq("passing-building")

      FactoryBot.create(:status, username: "collectiveidea", project_name: "baz", red: true, yellow: false)
      expect(device.status).to eq("failing-building")
    end
  end

  describe "#trigger" do
    context "when the device has a webhook_url" do
      it "sends a webhook" do
        device = FactoryBot.create(:device, webhook_url: "https://localhost/fake/path")
        allow(TriggerWebhook).to receive(:call)
        device.trigger
        expect(TriggerWebhook).to have_received(:call).with(device)
      end
    end

    context "when the device has an identifier" do
      it "sends a webhook" do
        device = FactoryBot.create(:device, identifier: "fake")
        allow(TriggerParticle).to receive(:call)
        device.trigger
        expect(TriggerParticle).to have_received(:call).with(device)
      end
    end
  end
end
