# frozen_string_literal: true

RSpec.describe "POST /auth/logout", type: :request do
  subject(:make_request) { post "/auth/logout", as: :json }

  let(:password) { "password1234" }
  let(:user) { create(:user, password: password) }

  context "when an auth cookie is present" do
    before do
      CommandTower.configure do |config|
        config.jwt.cookie.enabled = true
      end
      authenticate_request_with_cookie!(user)
      make_request
    end

    it { expect(response).to have_http_status(:ok) }

    it "returns logged_out in the envelope" do
      expect(response.parsed_body["data"]).to eq("message" => "logged_out")
    end

    it "clears the auth cookie" do
      expect(Array(response.headers["Set-Cookie"]).join).to include("#{CommandTower.config.jwt.cookie.name}=")
      expect(Array(response.headers["Set-Cookie"]).join).to match(/expires=|max-age=0/i)
    end
  end

  context "when no session is present" do
    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns logged_out" do
      expect(response.parsed_body["data"]["message"]).to eq("logged_out")
    end
  end
end
