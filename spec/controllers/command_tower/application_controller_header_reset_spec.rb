# frozen_string_literal: true

# Controller unit: X-Authorization-Reset header issuance and reuse.
# Cookie/CSRF journey coverage remains under spec/integration_test/auth/.
RSpec.describe CommandTower::ProtectedFixtureController, "authorization reset header", :protected_fixture, type: :controller do
  let(:user) { create(:user, :role_admin) }
  let(:reset_header) { CommandTower::ApplicationController::AUTHENTICATION_WITH_RESET.downcase }

  context "when the reset header is not requested" do
    before do
      set_jwt_token!(user:)
      get(:show)
    end

    it "does not send a regenerated token" do
      expect(response.headers[reset_header]).to be_nil
    end
  end

  context "when the reset header is requested" do
    before do
      set_jwt_token!(user:, with_reset: true)
      get(:show)
    end

    let(:generated_token) { response.headers[reset_header] }

    it "sends a regenerated token string" do
      expect(generated_token).to be_a(String)
    end

    it "issues an authenticatable token" do
      expect(CommandTower::Jwt::AuthenticateUser.(token: generated_token)).to be_success
    end

    context "when authenticating with the regenerated token" do
      before do
        set_jwt_token!(user:, token: generated_token)
        get(:show)
      end

      it "accepts the regenerated token" do
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
