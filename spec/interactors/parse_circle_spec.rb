require 'rails_helper'

describe ParseCircle do

  describe "set_colors" do
    before do
      @status = Status.new(service: "circle")
    end

    it "sets success to green" do
      ParseCircle.set_colors(@status, 'success')
      expect(@status.red).to be(false)
      expect(@status.yellow).to be(false)
    end

    it "sets fixed to green" do
      ParseCircle.set_colors(@status, 'fixed')
      expect(@status.red).to be(false)
      expect(@status.yellow).to be(false)
    end

    it "sets timedout to red" do
      ParseCircle.set_colors(@status, 'timedout')
      expect(@status.red).to be(true)
      expect(@status.yellow).to be(false)
    end

    it "sets running to yellow" do
      ParseCircle.set_colors(@status, 'running')
      expect(@status.yellow).to be(true)
    end

    it "keeps the red color if yellow" do
      @status.red = true
      ParseCircle.set_colors(@status, 'running')
      expect(@status.red).to be(true)
    end
  end
end
