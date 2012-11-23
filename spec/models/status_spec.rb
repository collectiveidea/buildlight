require 'spec_helper'

describe Status do
  describe "status_code=" do
    before do
      @status = Status.new
    end

    it "sets 0 to green" do
      @status.status_code = 0
      expect(@status.status).to eq("green")
    end

    it "sets 1 to red" do
      @status.status_code = 1
      expect(@status.status).to eq("red")
    end

    it "sets nil to yellow" do
      @status.status_code = nil
      expect(@status.status).to eq("yellow")
    end
  end
end
