require "rails_helper"

describe API::RedController do
  let!(:red1) { FactoryGirl.create :status, red: true, username: "user1" }
  let!(:red2) { FactoryGirl.create :status, red: true, username: "user2" }
  let!(:green1) { FactoryGirl.create :status, username: "user1" }
  let!(:green2) { FactoryGirl.create :status, username: "user2" }

  describe "#show" do
    render_views

    let!(:device) { FactoryGirl.create(:device, identifier: "abc123", usernames: ["user1"]) }

    it "responds with the list of red project names" do
      get :show, params: {id: "abc123"}

      expect(response.body).to match(/#{red1.project_name}/)
      expect(response.body).not_to match(/#{red2.project_name}/)
      expect(response.body).not_to match(/#{green1.project_name}/)
      expect(response.body).not_to match(/#{green2.project_name}/)
    end

    it "responds with the list of red projects serialized as json" do
      get :show, params: {id: "abc123", format: :json}

      response_json = JSON.parse(response.body)
      expect(response_json).to match_array([{"project_name" => red1.project_name, "username" => red1.username}])
    end
  end
end
