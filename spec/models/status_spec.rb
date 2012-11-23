require 'spec_helper'

describe Status do
  describe "status_code=" do
    before do
      @status = Status.new
    end

    it "sets 0 to green" do
      @status.status_code = 0
      expect(@status.red).to be_false
      expect(@status.yellow).to be_false
    end

    it "sets 1 to red" do
      @status.status_code = 1
      expect(@status.red).to be_true
      expect(@status.yellow).to be_false
    end

    it "sets nil to yellow" do
      @status.status_code = nil
      expect(@status.yellow).to be_true
    end

    it "keeps the red color if yellow" do
      @status.red = true
      @status.status_code = nil
      expect(@status.red).to be_true
    end
  end
end
