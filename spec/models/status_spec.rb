require 'rails_helper'

describe Status do
  describe "status_code=" do
    before do
      @status = Status.new
    end

    it "sets Passed to green" do
      @status.status_code = 'Passed'
      expect(@status.red).to be(false)
      expect(@status.yellow).to be(false)
    end

    it "sets Fixed to green" do
      @status.status_code = 'Fixed'
      expect(@status.red).to be(false)
      expect(@status.yellow).to be(false)
    end

    it "sets Still Failing to red" do
      @status.status_code = 'Still Failing'
      expect(@status.red).to be(true)
      expect(@status.yellow).to be(false)
    end

    it "sets Pending to yellow" do
      @status.status_code = 'Pending'
      expect(@status.yellow).to be(true)
    end

    it "keeps the red color if yellow" do
      @status.red = true
      @status.status_code = 'Pending'
      expect(@status.red).to be(true)
    end
  end

  describe "colors" do
    describe "without a username" do
      it "shows the red light on if the last status is red" do
        FactoryGirl.create :status, red: true
        colors = Status.colors
        expect(colors[:red]).to be(true)
      end

      it "shows the red and yellow lights on if the last status is yellow, but previous non-yellow was red" do
        FactoryGirl.create :status, red: true
        2.times { FactoryGirl.create :status, red: false, yellow: true }
        colors = Status.colors
        expect(colors[:yellow]).to be(true)
        expect(colors[:red]).to be(true)
      end

      it "shows the red light on if the last status is green, but another project is red" do
        FactoryGirl.create :status, red: true
        FactoryGirl.create :status, red: false
        colors = Status.colors
        expect(colors[:red]).to be(true)
      end
    end

    describe "with a username" do
      before do
        FactoryGirl.create :status, username: 'danielmorrison', red: true, yellow: true
      end

      it "shows the red light on if the last status is red" do
        FactoryGirl.create :status, username: 'collectiveidea', red: true
        colors = Status.colors('collectiveidea')
        expect(colors[:red]).to be(true)
      end

      it "shows the red and yellow lights on if the last status is yellow, but previous non-yellow was red" do
        FactoryGirl.create :status, username: 'collectiveidea', red: true
        2.times { FactoryGirl.create :status, username: 'collectiveidea', red: false, yellow: true }
        colors = Status.colors('collectiveidea')
        expect(colors[:yellow]).to be(true)
        expect(colors[:red]).to be(true)
      end

      it "shows the red light on if the last status is green, but another project is red" do
        FactoryGirl.create :status, username: 'collectiveidea', red: true
        FactoryGirl.create :status, username: 'collectiveidea', red: false
        colors = Status.colors('collectiveidea')
        expect(colors[:red]).to be(true)
      end
    end

    describe "with multiple usernames" do
      it "shows the red light on if the last status is red" do
        FactoryGirl.create :status, username: 'collectiveidea', red: true,  yellow: false
        FactoryGirl.create :status, username: 'danielmorrison', red: false, yellow: true
        colors = Status.colors(['collectiveidea', 'danielmorrison'])
        expect(colors[:red]).to be(true)
        expect(colors[:yellow]).to be(true)
      end
    end
  end

  describe "#name" do
    it "returns the full github-style name" do
      status = Status.new(username: "collectiveidea", project_name: "foo")
      expect(status.name).to eq("collectiveidea/foo")
    end
  end
end
