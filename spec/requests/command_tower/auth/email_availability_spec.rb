# frozen_string_literal: true

RSpec.describe "GET /auth/email/availability", type: :request do
  subject(:make_request) { get path, params: { email: email }, headers: headers }

  let(:path) { "/auth/email/availability" }
  let(:session_data) { create_signup_session! }
  let(:token) { session_data["signupSessionToken"] }
  let(:headers) { signup_session_headers(token) }

  before { flush_signup_rate_limits! }

  context "without a signup session token" do
    let(:headers) { {} }
    let(:email) { "newmember@example.com" }

    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }

    it "returns signup_session_missing" do
      expect(response.parsed_body["errors"].first["code"]).to eq("signup_session_missing")
    end
  end

  context "with an available email" do
    let(:email) { "newmember@example.com" }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns availability metadata" do
      expect(response.parsed_body["data"]).to include(
        "valid" => true,
        "available" => true,
        "message" => "Email is available"
      )
    end
  end

  context "with an existing email" do
    let!(:user) { create(:user, email: "taken@example.com", username: "takenuser") }
    let(:email) { "taken@example.com" }

    before { make_request }

    it "returns unavailable" do
      expect(response.parsed_body["data"]).to include(
        "valid" => true,
        "available" => false,
        "message" => "Email is already registered"
      )
    end
  end

  context "with invalid email format" do
    let(:email) { "not-an-email" }

    before { make_request }

    it "returns invalid" do
      expect(response.parsed_body["data"]).to include(
        "valid" => false,
        "available" => false
      )
    end
  end

  context "without an email param" do
    subject(:make_request) { get path, headers: headers }

    let(:email) { nil }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "returns a validation error naming the email field" do
      expect(response.parsed_body["errors"].first["code"]).to eq("validation_failed")
      expect(response.parsed_body["errors"].first["details"]).to eq("email" => "Email is required")
    end
  end

  context "when email availability is disabled" do
    let(:email) { "newmember@example.com" }

    before do
      CommandTower.configure do |config|
        config.signup_session.email_availability.enable = false
      end
      make_request
    end

    after do
      CommandTower.configure do |config|
        config.signup_session.email_availability.enable = true
      end
    end

    it { expect(response).to have_http_status(:not_found) }
  end
end
