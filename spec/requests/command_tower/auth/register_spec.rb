# frozen_string_literal: true

RSpec.describe "POST /auth/register", type: :request do
  subject(:make_request) { post path, params: params, as: :json }

  let(:path) { "/auth/register" }
  let(:password) { "correct-horse-9f3Qz!battery" }
  let(:params) do
    {
      first_name: "Jane",
      last_name: "Member",
      username: "janemember#{SecureRandom.hex(4)}",
      email: "jane-#{SecureRandom.hex(4)}@example.com",
      password: password,
      password_confirmation: password
    }
  end

  before { flush_signup_rate_limits! }

  context "with valid registration data" do
    before { make_request }

    let(:data) { response.parsed_body["data"] }

    it { expect(response).to have_http_status(:created) }

    it "returns the created user without a token" do
      expect(data["user"]).to include(
        "email" => params[:email],
        "username" => params[:username],
        "firstName" => "Jane",
        "lastName" => "Member",
        "emailValidated" => false
      )
      expect(data["token"]).to be_nil
      expect(data["message"]).to eq("Account created successfully")
    end
  end

  context "with the new shape and start_session" do
    let(:params) { { email: "new-#{SecureRandom.hex(4)}@example.com", password: password, start_session: true } }

    before { make_request }

    let(:data) { response.parsed_body["data"] }

    it "returns 201 with a session" do
      expect(response).to have_http_status(:created)
      expect(data["user"]["email"]).to eq(params[:email])
      expect(data["tokenExpiresAt"]).to be_present
      expect(response.headers["X-Authorization"].presence || data["token"]).to be_present
    end
  end

  context "with the new shape without start_session" do
    let(:params) { { email: "new-#{SecureRandom.hex(4)}@example.com", password: password } }

    before { make_request }

    it "returns 201 without a token" do
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]).not_to have_key("token")
      expect(response.headers["X-Authorization"]).to be_nil
    end
  end

  context "with a weak password" do
    let(:params) { { email: "weak-#{SecureRandom.hex(4)}@example.com", password: "password123" } }

    before { make_request }

    it "returns passwordRulesFailed" do
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].first["details"]).to include("passwordRulesFailed" => ["not_common"])
    end
  end

  context "when the same email registers past the per-email limit" do
    let(:params) { { email: "burst-#{SecureRandom.hex(4)}@example.com", password: "password123" } }

    it "answers 429 auth_rate_limited with retry_after_seconds" do
      6.times { post path, params: params, as: :json }

      error = response.parsed_body["errors"].first
      expect(response).to have_http_status(:too_many_requests)
      expect(error["code"]).to eq("auth_rate_limited")
      expect(error["details"]).to include("retry_after_seconds")
    end
  end

  context "with duplicate email" do
    let!(:existing_user) { create(:user, email: "jane@example.com", username: "existinguser") }
    let(:params) do
      {
        first_name: "Jane",
        last_name: "Member",
        username: "anotheruser",
        email: "jane@example.com",
        password: password,
        password_confirmation: password
      }
    end

    before { make_request }

    let(:error) { response.parsed_body["errors"].first }

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "returns email_already_registered with details" do
      expect(error["code"]).to eq("email_already_registered")
      expect(error["details"]).to include("email")
    end

    it "uses the friendly message" do
      expect(error["details"]["email"]).to eq(
        "You already have an account with this email. Sign in or reset your password."
      )
    end
  end

  context "with missing fields" do
    let(:params) { { email: "jane@example.com" } }

    before { make_request }

    let(:error) { response.parsed_body["errors"].first }

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "does not disclose which fields were missing" do
      expect(error["code"]).to eq("validation_failed")
      expect(error["details"]).to eq("base" => "Missing required fields")
    end
  end
end
