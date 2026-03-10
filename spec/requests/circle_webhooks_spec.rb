require "rails_helper"

describe "Webhooks from Circle CI" do
  it "receives a json payload" do
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

  it "triggers a webhook" do
    stub = stub_request(:post, "https://localhost/fake/path")
      .with(body: {colors: {red: false, yellow: false, green: true}}.to_json)
    device = FactoryBot.create(:device, usernames: ["collectiveidea"], webhook_url: "https://localhost/fake/path")
    device.update_column(:status, nil)
    post "/", params: json_fixture("circle.json"), headers: {"content-type": "application/json", "Circleci-Event-Type": "workflow-completed"}
    expect(stub).to have_been_requested
  end
end
