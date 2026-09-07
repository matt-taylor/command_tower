# frozen_string_literal: true

RSpec.describe "Me experience states", :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:complete_params) do
    {
      experienceKey: "welcome",
      scopeType: "example_scope",
      scopeIdentifier: "42",
      version: "v1",
    }
  end

  around do |example|
    previous = CommandTower.config.application.host_key
    CommandTower.config.application.host_key = host_key
    example.run
  ensure
    CommandTower.config.application.host_key = previous
  end

  let(:host_key) { "command_tower" }

  it "rejects unauthenticated index" do
    get "/me/experience-states"

    expect(response).to have_http_status(:unauthorized)
  end

  context "when the caller lacks roles" do
    let(:unprivileged_user) { create(:user, roles: []) }
    let(:unprivileged_headers) { authenticate_request_with_bearer!(unprivileged_user) }

    before { get "/me/experience-states", headers: unprivileged_headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  it "returns an empty collection when no completions exist" do
    get "/me/experience-states", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"]).to eq("experienceStates" => [])
    expect(response.body).not_to include("showWelcome")
  end

  context "after completing an experience state" do
    before { post "/me/experience-states/complete", headers: headers, params: complete_params, as: :json }

    it "returns the durable fact" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to include(
        "hostKey" => "command_tower",
        "experienceKey" => "welcome",
        "scopeType" => "example_scope",
        "scopeIdentifier" => "42",
        "version" => "v1",
      )
      expect(response.parsed_body.dig("data", "completedAt")).to be_present
      expect(response.body).not_to include("showWelcome")
    end

    it "lists the completed row" do
      get "/me/experience-states", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "experienceStates").size).to eq(1)
      expect(response.parsed_body.dig("data", "experienceStates", 0, "scopeIdentifier")).to eq("42")
      expect(response.body).not_to include("showWelcome")
    end
  end

  context "when completing twice" do
    before do
      post "/me/experience-states/complete", headers: headers, params: complete_params, as: :json
      @first_completed_at = response.parsed_body.dig("data", "completedAt")
      post "/me/experience-states/complete", headers: headers, params: complete_params, as: :json
    end

    it "returns the same completedAt" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "completedAt")).to eq(@first_completed_at)
    end
  end

  context "when another host_key row exists" do
    before do
      create(
        :user_experience_state,
        user:,
        host_key: "other_host",
        experience_key: "welcome",
        scope_type: "example_scope",
        scope_identifier: "42",
        version: "v1",
      )
    end

    it "excludes other host rows from the list" do
      get "/me/experience-states", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "experienceStates")).to eq([])
    end
  end

  context "when host_key is blank" do
    let(:host_key) { "" }

    it "returns 503 on index" do
      get "/me/experience-states", headers: headers

      expect(response).to have_http_status(:service_unavailable)
    end

    it "returns 503 on complete" do
      post "/me/experience-states/complete", headers: headers, params: complete_params, as: :json

      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
