require "rails_helper"

describe ParseGithub do
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
