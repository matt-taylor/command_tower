# frozen_string_literal: true

RSpec.describe "DELETE /auth/impersonation-session", :with_rbac_setup, type: :request do
  let(:operator) { create(:user, :role_impersonation_operator) }
  let(:target) { create(:user, roles: ["member"]) }
  let!(:session) { create(:impersonation_session, actor: operator, target:) }
  let(:headers) { authenticate_impersonation_with_bearer!(operator, session) }

  context "when an active overlay is stopped" do
    before { delete "/auth/impersonation-session", headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it "re-issues an administrator JWT without the overlay claim" do
      expect(
        CommandTower::Jwt::Decode.call(token: response.headers["X-Authorization-Reset"]).payload[:user_id]
      ).to eq(operator.id)
      expect(
        CommandTower::Jwt::Decode.call(token: response.headers["X-Authorization-Reset"]).payload[:impersonation_session_id]
      ).to be_nil
    end

    it "ends the session as manual" do
      expect(session.reload.end_reason).to eq("manual")
    end
  end

  context "when stop is called twice" do
    before do
      delete "/auth/impersonation-session", headers: headers
      delete "/auth/impersonation-session", headers: {
        "Authorization" => "Bearer #{response.headers['X-Authorization-Reset']}"
      }
    end

    it "returns to self on the first call and rejects a missing overlay on the second" do
      expect(response).to have_http_status(:unprocessable_entity)
      expect(CommandTower::Audit::Event.where(action: "impersonation_ended").count).to eq(1)
    end
  end

  context "when the overlay is already expired" do
    let!(:session) do
      create(
        :impersonation_session,
        actor: operator,
        target:,
        idle_expires_at: 1.minute.ago,
        absolute_expires_at: 1.hour.from_now
      )
    end

    before { delete "/auth/impersonation-session", headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it "still returns a self token" do
      expect(
        CommandTower::Jwt::Decode.call(token: response.headers["X-Authorization-Reset"]).payload[:impersonation_session_id]
      ).to be_nil
    end
  end

  context "without an overlay claim" do
    let(:headers) { authenticate_request_with_bearer!(operator) }

    before { delete "/auth/impersonation-session", headers: headers }

    it { expect(response).to have_http_status(:unprocessable_entity) }
  end
end
