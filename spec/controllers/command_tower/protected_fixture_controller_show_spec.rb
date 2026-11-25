# frozen_string_literal: true

# Controller unit: device session 401s from ApplicationController#authenticate_user!.
RSpec.describe CommandTower::ProtectedFixtureController, "#show", :protected_fixture, type: :controller do
  let(:user) { create(:user, :role_admin) }
  let(:device_session) { create(:device_session, user:, **session_attrs) }
  let(:token) { CommandTower::Jwt::LoginCreate.call(user:, device_session:).token }

  before do
    set_jwt_token!(user:, token:)
    get(:show)
  end

  context "when the session is revoked" do
    let(:session_attrs) { { revoked_at: 1.minute.ago, revoked_reason: "logout" } }

    it { expect(response).to have_http_status(:unauthorized) }

    it "renders session_revoked in the error envelope" do
      expect(response.parsed_body).to eq(
        "data" => nil,
        "errors" => [{ "code" => "session_revoked", "message" => "Your session has ended. Please sign in again." }]
      )
    end
  end

  context "when the session is past its absolute expiry" do
    let(:session_attrs) { { absolute_expires_at: 1.minute.ago } }

    it { expect(response).to have_http_status(:unauthorized) }

    it "renders session_expired in the error envelope" do
      expect(response.parsed_body).to eq(
        "data" => nil,
        "errors" => [{ "code" => "session_expired", "message" => "Your session has expired. Please sign in again." }]
      )
    end
  end

  context "when the session is live" do
    let(:session_attrs) { {} }

    it { expect(response).to have_http_status(:ok) }
  end
end
