require "rails_helper"

describe ParseGithub do
  describe "call" do
    it "uses worflow column to differentiate between statuses" do
      other_status = FactoryBot.create :status, service: "github", username: "collectiveidea", project_name: "buildlight", workflow: "Other Workflow", red: true
      ParseGithub.call(JSON.parse(json_fixture("github.json")))
      expect(other_status.reload.red).to be(true)
      expect(Status.where(service: "github", username: "collectiveidea", project_name: "buildlight").count).to eq(2)
    end

    it "does not raise on an unknown conclusion" do
      payload = JSON.parse(json_fixture("github.json")).merge("status" => "something_new")
      expect { ParseGithub.call(payload) }.not_to raise_error
      expect(Status.find_by(service: "github", username: "collectiveidea", project_name: "buildlight").yellow).to be(false)
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

    %w[failure timed_out startup_failure].each do |conclusion|
      it "sets '#{conclusion}' to red" do
        ParseGithub.set_colors(@status, conclusion)
        expect(@status.red).to be(true)
        expect(@status.yellow).to be(false)
      end
    end

    it "sets '' to yellow" do
      ParseGithub.set_colors(@status, "")
      expect(@status.yellow).to be(true)
    end

    it "sets nil to yellow" do
      ParseGithub.set_colors(@status, nil)
      expect(@status.yellow).to be(true)
    end

    it "keeps the red color if yellow" do
      @status.red = true
      ParseGithub.set_colors(@status, "")
      expect(@status.red).to be(true)
    end

    %w[cancelled skipped neutral stale action_required].each do |conclusion|
      it "clears yellow but keeps red on '#{conclusion}'" do
        @status.red = true
        @status.yellow = true
        ParseGithub.set_colors(@status, conclusion)
        expect(@status.red).to be(true)
        expect(@status.yellow).to be(false)
      end

      it "clears yellow but keeps green on '#{conclusion}'" do
        @status.red = false
        @status.yellow = true
        ParseGithub.set_colors(@status, conclusion)
        expect(@status.red).to be(false)
        expect(@status.yellow).to be(false)
      end
    end

    it "treats an unknown conclusion as inconclusive and logs it" do
      @status.red = true
      @status.yellow = true
      expect(Rails.logger).to receive(:warn).with(/unknown conclusion "something_new"/)
      ParseGithub.set_colors(@status, "something_new")
      expect(@status.red).to be(true)
      expect(@status.yellow).to be(false)
    end
  end
end
