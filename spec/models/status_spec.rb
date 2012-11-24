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

  describe "colors" do
    describe "without a username" do
      it "shows the red light on if the last status is red" do
        FactoryGirl.create :status, red: true
        colors = Status.colors
        expect(colors[:red]).to be_true
      end

      it "shows the red and yellow lights on if the last status is yellow, but previous non-yellow was red" do
        FactoryGirl.create :status, red: true
        2.times { FactoryGirl.create :status, red: false, yellow: true }
        colors = Status.colors
        expect(colors[:yellow]).to be_true
        expect(colors[:red]).to be_true
      end

      it "shows the red light on if the last status is green, but another project is red" do
        FactoryGirl.create :status, red: true
        FactoryGirl.create :status, red: false
        colors = Status.colors
        expect(colors[:red]).to be_true
      end
    end

    describe "with a username" do
      before do
        FactoryGirl.create :status, username: 'danielmorrison', red: true, yellow: true
      end

      it "shows the red light on if the last status is red" do
        FactoryGirl.create :status, username: 'collectiveidea', red: true
        colors = Status.colors('collectiveidea')
        expect(colors[:red]).to be_true
      end

      it "shows the red and yellow lights on if the last status is yellow, but previous non-yellow was red" do
        FactoryGirl.create :status, username: 'collectiveidea', red: true
        2.times { FactoryGirl.create :status, username: 'collectiveidea', red: false, yellow: true }
        colors = Status.colors('collectiveidea')
        expect(colors[:yellow]).to be_true
        expect(colors[:red]).to be_true
      end

      it "shows the red light on if the last status is green, but another project is red" do
        FactoryGirl.create :status, username: 'collectiveidea', red: true
        FactoryGirl.create :status, username: 'collectiveidea', red: false
        colors = Status.colors('collectiveidea')
        expect(colors[:red]).to be_true
      end
    end

    describe "with multiple usernames" do
      it "shows the red light on if the last status is red" do
        FactoryGirl.create :status, username: 'collectiveidea', red: true,  yellow: false
        FactoryGirl.create :status, username: 'danielmorrison', red: false, yellow: true
        colors = Status.colors(['collectiveidea', 'danielmorrison'])
        expect(colors[:red]).to be_true
        expect(colors[:yellow]).to be_true
      end
    end
  end
end
