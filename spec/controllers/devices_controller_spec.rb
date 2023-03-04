require "rails_helper"

describe DevicesController do
  describe "show" do
    before do
      FactoryBot.create :status, username: "collectiveidea", red: false
      FactoryBot.create :status, username: "danielmorrison", red: true
      @device = FactoryBot.create :device, usernames: ["collectiveidea"], slug: "office"
    end

    it "shows the status for a single device by id" do
      get :show, params: {id: device.id, format: :json}
      json = JSON.parse(response.body)
      expect(json["red"]).to be(false)
    end

    it "shows the status for a single device by slug" do
      get :show, params: {id: device.slug, format: :json}
      json = JSON.parse(response.body)
      expect(json["red"]).to be(false)
    end
  end
end
