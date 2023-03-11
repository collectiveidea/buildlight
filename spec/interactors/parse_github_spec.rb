require "rails_helper"

describe ParseGithub do
  describe "call" do
    it "uses worflow column to differentiate between statuses" do
      other_status = FactoryBot.create :status, service: "github", username: "collectiveidea", project_name: "buildlight", workflow: "Other Workflow", red: true
      ParseGithub.call(JSON.parse(json_fixture("github.json")))
      expect(other_status.reload.red).to be(true)
      expect(Status.where(service: "github", username: "collectiveidea", project_name: "buildlight").count).to eq(2)
    end
  end

  describe "set_colors" do
    before do
      @status = Status.new(service: "github")
    end

    it "sets 'success' to green" do
      ParseGithub.set_colors(@status, "success")
      expect(@status.red).to be(false)
      expect(@status.yellow).to be(false)
    end

    it "sets 'failure' to red" do
      ParseGithub.set_colors(@status, "failure")
      expect(@status.red).to be(true)
      expect(@status.yellow).to be(false)
    end

    it "sets '' to yellow" do
      ParseGithub.set_colors(@status, "")
      expect(@status.yellow).to be(true)
    end

    it "keeps the red color if yellow" do
      @status.red = true
      ParseGithub.set_colors(@status, "")
      expect(@status.red).to be(true)
    end
  end
end
