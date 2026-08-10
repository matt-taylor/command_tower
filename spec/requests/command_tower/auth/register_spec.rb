# frozen_string_literal: true

RSpec.describe "POST /auth/register", type: :request do
  subject(:make_request) { post path, params: params, as: :json }

  let(:path) { "/auth/register" }
  let(:password) { "password1234" }
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
