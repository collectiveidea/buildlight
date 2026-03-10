require "rails_helper"

describe WebhooksController do
  describe "POST create" do
    describe "unknown data" do
      it "ignores non-useful data" do
        expect(Status.count).to eq(0)
        data = {foo: "bar"}
        post :create, params: data
        expect(response.code).to eq("400")
        expect(Status.count).to eq(0)
      end
    end

    describe "from Travis CI" do
      it "recieves a json payload" do
        post :create, params: {payload: json_fixture("travis.json")}
        expect(response).to be_successful
      end

      it "saves useful data" do
        post :create, params: {payload: json_fixture("travis.json")}
        status = Status.order("created_at DESC").first
        expect(status.red).to be(false)
        expect(status.service).to eq("travis")
        expect(status.project_id).to eq("347744")
        expect(status.project_name).to eq("buildlight")
        expect(status.username).to eq("collectiveidea")
      end

      it "ignores pull requests" do
        expect(Status.count).to eq(0)
        post :create, params: {payload: json_fixture("travis.json").sub(%("type":"push"), %("type":"pull_request"))}
        expect(Status.count).to eq(0)
      end

      it "triggers a webhook" do
        stub = stub_request(:post, "https://localhost/fake/path")
          .with(body: {colors: {red: false, yellow: false, green: true}}.to_json)
        device = FactoryBot.create(:device, usernames: ["collectiveidea"], webhook_url: "https://localhost/fake/path")
        device.update_column(:status, nil)
        post :create, params: {payload: json_fixture("travis.json")}
        expect(stub).to have_been_requested
      end
    end

    describe "from GitHub Actions" do
      it "recieves a json payload" do
        post :create, params: JSON.parse(json_fixture("github.json"))
        expect(response).to be_successful
      end

      it "saves useful data" do
        post :create, params: JSON.parse(json_fixture("github.json"))
        status = Status.order("created_at DESC").first
        expect(status.red).to be(false)
        expect(status.service).to eq("github")
        expect(status.project_id).to be_nil
        expect(status.project_name).to eq("buildlight")
        expect(status.username).to eq("collectiveidea")
      end

      it "triggers a webhook" do
        stub = stub_request(:post, "https://localhost/fake/path")
          .with(body: {colors: {red: false, yellow: false, green: true}}.to_json)
        device = FactoryBot.create(:device, usernames: ["collectiveidea"], webhook_url: "https://localhost/fake/path")
        device.update_column(:status, nil)
        post :create, params: JSON.parse(json_fixture("github.json"))
        expect(stub).to have_been_requested
      end
    end
  end
end
