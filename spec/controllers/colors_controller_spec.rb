require "rails_helper"

describe ColorsController do
  describe "index" do
    it "shows the red light on if the last status is red" do
      FactoryBot.create :status, red: true
      get :index, params: {format: :json}
      json = JSON.parse(response.body)
      expect(json["red"]).to be_truthy
    end

    it "shows the red and yellow lights on if the last status is yellow, but previous non-yellow was red" do
      FactoryBot.create :status, red: true
      2.times { FactoryBot.create :status, red: false, yellow: true }
      get :index, params: {format: :json}
      json = JSON.parse(response.body)
      expect(json["yellow"]).to be(true)
      expect(json["red"]).to be_truthy
    end

    it "shows the red light on if the last status is green, but another project is red" do
      FactoryBot.create :status, red: true
      FactoryBot.create :status, red: false
      get :index, params: {format: :json}
      json = JSON.parse(response.body)
      expect(json["red"]).to be_truthy
    end
  end

  describe "show" do
    it "shows the status for a single user" do
      FactoryBot.create :status, username: "collectiveidea", red: false
      FactoryBot.create :status, username: "danielmorrison", red: true
      get :show, params: {id: "collectiveidea", format: :json}
      json = JSON.parse(response.body)
      expect(json["red"]).to be(false)
    end

    it "shows the status for all users separated by a comma" do
      FactoryBot.create :status, username: "collectiveidea", red: false, yellow: true
      FactoryBot.create :status, username: "danielmorrison", red: true, yellow: false
      get :show, params: {id: "collectiveidea,danielmorrison", format: :json}
      json = JSON.parse(response.body)
      expect(json["red"]).to be_truthy
      expect(json["yellow"]).to be(true)
    end
  end
end
