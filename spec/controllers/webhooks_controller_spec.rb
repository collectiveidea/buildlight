require 'rails_helper'

describe WebhooksController do
  describe 'POST create' do
    before do
      allow(Particle).to receive(:publish)
    end

    it 'recieves a json payload' do
      post :create, params: {payload: json_fixture('travis.json')}
      expect(response).to be_success
    end

    it 'saves useful data' do
      post :create, params: {payload: json_fixture('travis.json')}
      status = Status.order("created_at DESC").first
      expect(status.red).to be(false)
      expect(status.project_id).to eq("347744")
      expect(status.project_name).to eq("buildlight")
      expect(status.username).to eq("collectiveidea")
    end

    it 'notifies Particle' do
      FactoryGirl.create(:device, usernames: ["collectiveidea"])
      expect(Particle).to receive(:publish).with({name: "build_state", data: "passing", ttl: 3600, private: false})
      post :create, params: {payload: json_fixture('travis.json')}
    end

    it 'ignores pull requests' do
      expect(Status.count).to eq(0)
      post :create, params: {payload: json_fixture('travis.json').sub(%("type":"push"), %("type":"pull_request"))}
      expect(Status.count).to eq(0)
    end
  end
end
