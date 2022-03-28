require "rails_helper"

describe WebhooksController do
  describe "POST create" do
    before do
      allow(Particle).to receive(:publish)
    end

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

      it "notifies Particle" do
        FactoryBot.create(:device, usernames: ["collectiveidea"])
        expect(Particle).to receive(:publish).with(name: "build_state", data: "passing", ttl: 3600, private: false)
        post :create, params: {payload: json_fixture("travis.json")}
      end
    end

    describe "from Circle CI" do
      it "recieves a json payload" do
        post :create, params: JSON.parse(json_fixture("circle.json"))
        expect(response).to be_successful
      end

      it "saves useful data" do
        post :create, params: JSON.parse(json_fixture("circle.json"))
        status = Status.order("created_at DESC").first
        expect(status.red).to be(false)
        expect(status.service).to eq("circle")
        expect(status.project_id).to be_nil
        expect(status.project_name).to eq("buildlight")
        expect(status.username).to eq("collectiveidea")
      end

      it "ignores pull requests" do
        expect(Status.count).to eq(0)
        data = JSON.parse(json_fixture("circle_pr.json"))
        data["payload"]["pull_requests"] = [{not: "empty"}]
        post :create, params: data
        expect(Status.count).to eq(0)
      end

      it "notifies Particle" do
        FactoryBot.create(:device, usernames: ["collectiveidea"])
        expect(Particle).to receive(:publish).with(name: "build_state", data: "passing", ttl: 3600, private: false)
        post :create, params: JSON.parse(json_fixture("circle.json"))
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

      it "notifies Particle" do
        FactoryBot.create(:device, usernames: ["collectiveidea"])
        expect(Particle).to receive(:publish).with(name: "build_state", data: "passing", ttl: 3600, private: false)
        post :create, params: JSON.parse(json_fixture("github.json"))
      end
    end
  end
end
