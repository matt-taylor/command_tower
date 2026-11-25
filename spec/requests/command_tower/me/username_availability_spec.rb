# frozen_string_literal: true

RSpec.describe "GET /me/username/availability", :with_rbac_setup, type: :request do
  subject(:make_request) { get "/me/username/availability", params: params, headers: headers }

  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:params) { { username: "fresh_name" } }
  let(:user) { create(:user, roles: ["member"], username: nil, email_validated: false) }
  let(:username_config) { { self_service: true, self_change: false } }
  let(:data) { response.parsed_body["data"] }

  before do
    allow(CommandTower.config.username).to receive_messages(username_config)
  end

  context "without authentication" do
    let(:headers) { {} }

    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "when an unverified user without a username asks" do
    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "reports the name available" do
      expect(data).to include("valid" => true, "available" => true)
    end
  end

  context "when the name belongs to an existing user" do
    before do
      create(:user, username: "taken_name")
      get "/me/username/availability", params: { username: "taken_name" }, headers: headers
    end

    it "reports the name unavailable" do
      expect(data).to include("available" => false)
    end
  end

  context "when the name looks like an email" do
    let(:params) { { username: "person@example.com" } }

    before { make_request }

    it "reports the name invalid" do
      expect(data).to include("valid" => false, "available" => false)
    end
  end

  context "when the user may not change their username" do
    let(:user) { create(:user, roles: ["member"], username: "existing_name") }

    before { make_request }

    it { expect(response).to have_http_status(:forbidden) }

    it "returns username_change_not_allowed" do
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("username_change_not_allowed")
    end
  end

  context "when the username is missing" do
    let(:params) { {} }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }
  end

  context "when the per-user daily limit is exceeded" do
    before do
      counts = [101, 1]
      allow(CommandTower::Services::RateLimits::Check).to receive(:call) do
        Struct.new(:data) { def failure? = false }.new({ count: counts.shift, ttl: 120 })
      end
      make_request
    end

    it { expect(response).to have_http_status(:too_many_requests) }
  end

  context "when the per-IP daily limit is exceeded" do
    before do
      counts = [1, 301]
      allow(CommandTower::Services::RateLimits::Check).to receive(:call) do
        Struct.new(:data) { def failure? = false }.new({ count: counts.shift, ttl: 120 })
      end
      make_request
    end

    it { expect(response).to have_http_status(:too_many_requests) }
  end
end
