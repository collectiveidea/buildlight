require "rails_helper"

describe ParseTravis do
  describe "set_colors" do
    before do
      @status = Status.new
    end

    it "sets Passed to green" do
      ParseTravis.set_colors(@status, "Passed")
      expect(@status.red).to be(false)
      expect(@status.yellow).to be(false)
    end

    it "sets Fixed to green" do
      ParseTravis.set_colors(@status, "Fixed")
      expect(@status.red).to be(false)
      expect(@status.yellow).to be(false)
    end

    it "sets Still Failing to red" do
      ParseTravis.set_colors(@status, "Still Failing")
      expect(@status.red).to be(true)
      expect(@status.yellow).to be(false)
    end

    it "sets Pending to yellow" do
      ParseTravis.set_colors(@status, "Pending")
      expect(@status.yellow).to be(true)
    end

    it "keeps the red color if yellow" do
      @status.red = true
      ParseTravis.set_colors(@status, "Pending")
      expect(@status.red).to be(true)
    end
  end
end
