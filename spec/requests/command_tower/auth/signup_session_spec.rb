# frozen_string_literal: true

RSpec.describe "POST /auth/signup-session", type: :request do
  subject(:make_request) { post path }

  let(:path) { "/auth/signup-session" }

  before do
    flush_signup_rate_limits!
    make_request
  end

  it { expect(response).to have_http_status(:created) }

  it "returns a signup session token and expiration" do
    expect(response.parsed_body["data"]["signupSessionToken"]).to be_present
    expect(response.parsed_body["data"]["expiresAt"]).to be_present
  end

  context "when the token is accepted by availability endpoints" do
    subject(:availability_response) do
      get "/auth/username/availability",
          params: { username: "brandnewuser" },
          headers: signup_session_headers(response.parsed_body["data"]["signupSessionToken"])
      response
    end

    before { availability_response }

    it { expect(availability_response).to have_http_status(:ok) }
  end

  context "when the client ip exceeds the burst ceiling" do
    let(:limit) { CommandTower.config.signup_session.rate_limits.ip_issue_burst }

    before { limit.times { post path } }

    it "returns too_many_requests" do
      post path

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body["errors"].first["code"]).to eq("signup_ip_rate_limited")
    end
  end
end
