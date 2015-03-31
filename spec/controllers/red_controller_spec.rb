require 'rails_helper'

describe RedController do
  let!(:red1) { FactoryGirl.create :status, red: true, username: 'user1' }
  let!(:red2) { FactoryGirl.create :status, red: true, username: 'user2' }
  let!(:green1) { FactoryGirl.create :status, username: 'user1' }
  let!(:green2) { FactoryGirl.create :status, username: 'user2' }

  describe "#index" do
    render_views

    it "responds with the list of red project names" do
      get :index

      expect(response.body).to match(/#{red1.project_name}/)
      expect(response.body).to match(/#{red2.project_name}/)
      expect(response.body).not_to match(/#{green1.project_name}/)
      expect(response.body).not_to match(/#{green2.project_name}/)
    end

    it "responds with the list of red projects serialized as json" do
      get :index, format: :json

      expect(response.body).to eq([red1, red2].to_json)
    end
  end

  describe "#show" do
    render_views

    it "responds with the list of red project names" do
      get :show, id: 'user1'

      expect(response.body).to match(/#{red1.project_name}/)
      expect(response.body).not_to match(/#{red2.project_name}/)
      expect(response.body).not_to match(/#{green1.project_name}/)
      expect(response.body).not_to match(/#{green2.project_name}/)
    end

    it "responds with the list of red projects serialized as json" do
      get :show, id: 'user1', format: :json

      expect(response.body).to eq([red1].to_json)
    end
  end
end
