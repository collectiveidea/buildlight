require "rails_helper"

describe "Webhooks from Circle CI" do
  before do
    allow(Particle).to receive(:publish)
  end

  it "recieves a json payload" do
    post "/", params: json_fixture("circle.json"), headers: {"content-type": "application/json", "Circleci-Event-Type": "workflow-completed"}
    expect(response).to be_successful
  end

  it "saves useful data" do
    post "/", params: json_fixture("circle.json"), headers: {"content-type": "application/json", "Circleci-Event-Type": "workflow-completed"}
    status = Status.order("created_at DESC").first
    expect(status.red).to be(false)
    expect(status.service).to eq("circle")
    expect(status.project_id).to be_nil
    expect(status.project_name).to eq("buildlight")
    expect(status.username).to eq("collectiveidea")
  end

  it "ignores pull requests" do
    expect(Status.count).to eq(0)
    post "/", params: json_fixture("circle_pr.json"), headers: {"content-type": "application/json", "Circleci-Event-Type": "workflow-completed"}
    expect(Status.count).to eq(0)
  end

  it "notifies Particle" do
    FactoryBot.create(:device, :with_identifier, usernames: ["collectiveidea"])
    allow(Particle).to receive(:publish)
    post "/", params: json_fixture("circle.json"), headers: {"content-type": "application/json", "Circleci-Event-Type": "workflow-completed"}
    expect(Particle).to have_received(:publish).with(name: "build_state", data: "passing", ttl: 3600, private: false)
  end
end
