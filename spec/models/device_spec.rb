require "rails_helper"

RSpec.describe Device, type: :model do
  describe "#statuses" do
    let!(:status1) { FactoryGirl.create(:status, username: "collectiveidea", project_name: "foo") }
    let!(:status2) { FactoryGirl.create(:status, username: "collectiveidea", project_name: "bar") }
    let!(:status3) { FactoryGirl.create(:status, username: "deadmanssnitch", project_name: "foo") }
    let!(:status4) { FactoryGirl.create(:status, username: "deadmanssnitch", project_name: "bar") }
    let!(:status5) { FactoryGirl.create(:status, username: "inchworm", project_name: "foo") }

    it "includes status by project" do
      device = FactoryGirl.create(:device, usernames: [], projects: ["collectiveidea/bar", "deadmanssnitch/foo"])

      expect(device.statuses.size).to eq(2)
      expect(device.statuses).to include(status2)
      expect(device.statuses).to include(status3)
    end

    it "includes status by username" do
      device = FactoryGirl.create(:device, usernames: ["collectiveidea", "inchworm"], projects: [])

      expect(device.statuses.size).to eq(3)
      expect(device.statuses).to include(status1)
      expect(device.statuses).to include(status2)
      expect(device.statuses).to include(status5)
    end

    it "includes status by username and project at the same time" do
      device = FactoryGirl.create(:device, usernames: ["collectiveidea"], projects: ["deadmanssnitch/bar"])

      expect(device.statuses.size).to eq(3)
      expect(device.statuses).to include(status1)
      expect(device.statuses).to include(status2)
      expect(device.statuses).to include(status4)
    end
  end

  describe "#status" do
    it "returns the status for the device" do
      FactoryGirl.create(:status, username: "collectiveidea", project_name: "foo", red: false, yellow: false)
      FactoryGirl.create(:status, username: "collectiveidea", project_name: "bar", red: false, yellow: true)
      FactoryGirl.create(:status, username: "deadmanssnitch", project_name: "foo", red: false, yellow: false)
      FactoryGirl.create(:status, username: "deadmanssnitch", project_name: "bar", red: true, yellow: true)

      device = FactoryGirl.create(:device, usernames: ["collectiveidea"], projects: ["deadmanssnitch/foo"])
      expect(device.status).to eq("passing-building")

      FactoryGirl.create(:status, username: "collectiveidea", project_name: "baz", red: true, yellow: false)
      expect(device.status).to eq("failing-building")
    end
  end
end
