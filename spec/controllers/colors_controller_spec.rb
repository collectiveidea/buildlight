require 'spec_helper'

describe ColorsController do
  describe "index" do
    it "shows the red light on if the last status is red" do
      FactoryGirl.create :status, red: true
      get :index
      json = JSON.parse(response.body)
      expect(json['red']).to be_true
    end

    it "shows the red and yellow lights on if the last status is yellow, but previous non-yellow was red" do
      FactoryGirl.create :status, red: true
      2.times { FactoryGirl.create :status, red: false, yellow: true }
      get :index
      json = JSON.parse(response.body)
      expect(json['yellow']).to be_true
      expect(json['red']).to be_true
    end

    it "shows the red light on if the last status is green, but another project is red" do
      FactoryGirl.create :status, red: true
      FactoryGirl.create :status, red: false
      get :index
      json = JSON.parse(response.body)
      expect(json['red']).to be_true
    end
  end
end
