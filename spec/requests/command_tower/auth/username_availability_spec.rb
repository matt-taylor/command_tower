# frozen_string_literal: true

RSpec.describe "GET /auth/username/availability", type: :request do
  subject(:make_request) { get path, params: { username: username }, headers: headers }

  let(:path) { "/auth/username/availability" }
  let(:session_data) { create_signup_session! }
  let(:token) { session_data["signupSessionToken"] }
  let(:headers) { signup_session_headers(token) }

  before { flush_signup_rate_limits! }

  context "without a signup session token" do
    let(:headers) { {} }
    let(:username) { "availableuser123" }

    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }

    it "returns signup_session_missing" do
      expect(response.parsed_body["errors"].first["code"]).to eq("signup_session_missing")
    end
  end

  context "with a bearer token instead of a signup token" do
    let(:headers) { { "Authorization" => "Bearer sometoken" } }
    let(:username) { "availableuser123" }

    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }

    it "returns signup_session_invalid" do
      expect(response.parsed_body["errors"].first["code"]).to eq("signup_session_invalid")
    end
  end

  context "with an available username" do
    let(:username) { "availableuser123" }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns availability metadata" do
      expect(response.parsed_body["data"]).to include(
        "valid" => true,
        "available" => true,
        "message" => "Username is available"
      )
    end
  end

  context "with a taken username" do
    let!(:user) { create(:user, username: "takenuser") }
    let(:username) { "takenuser" }

    before { make_request }

    it "returns unavailable" do
      expect(response.parsed_body["data"]).to include(
        "valid" => true,
        "available" => false,
        "message" => "Username is already taken"
      )
    end
  end

  context "with an invalid username format" do
    let(:username) { "ab" }

    before { make_request }

    it "returns invalid format metadata" do
      expect(response.parsed_body["data"]["valid"]).to be(false)
    end
  end

  context "without a username param" do
    subject(:make_request) { get path, headers: headers }

    let(:username) { nil }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "returns a validation error naming the username field" do
      expect(response.parsed_body["errors"].first["code"]).to eq("validation_failed")
      expect(response.parsed_body["errors"].first["details"]).to eq("username" => "Username is required")
    end
  end

  context "when realtime username check is disabled" do
    let(:username) { "availableuser123" }

    before do
      CommandTower.configure do |config|
        config.username.realtime_username_check.enable = false
      end
      make_request
    end

    after do
      CommandTower.configure do |config|
        config.username.realtime_username_check.enable = true
      end
    end

    it { expect(response).to have_http_status(:not_found) }
  end
end
