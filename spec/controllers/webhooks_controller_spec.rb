require 'spec_helper'

describe WebhooksController do
  describe 'POST create' do
    it 'recieves a json payload' do
      post_json '/webhooks', json_fixture('travis.json')
      expect(response).to be_success
    end

    it 'saves useful data' do
      post_json '/webhooks', json_fixture('travis.json')
      status = Status.order("created_at DESC").first
      expect(status.status).to eq("Passed")
      expect(status.project_id).to eq("1")
      expect(status.project_name).to eq("minimal")
    end
  end
end
