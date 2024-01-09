require "rails_helper"

describe ParseCircle do
  describe "set_colors" do
    before do
      @status = Status.new(service: "circle")
    end

    it "sets success to green" do
      ParseCircle.set_colors(@status, "success")
      expect(@status.red).to be(false)
      expect(@status.yellow).to be(false)
    end

    it "sets failed to red" do
      ParseCircle.set_colors(@status, "failed")
      expect(@status.red).to be(true)
      expect(@status.yellow).to be(false)
    end
  end
end
