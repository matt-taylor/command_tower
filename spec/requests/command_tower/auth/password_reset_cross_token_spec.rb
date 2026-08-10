# frozen_string_literal: true

# Request: recovery token rejected on non-recovery routes.
RSpec.describe "password reset cross-token rejection", type: :request do
  before { flush_password_recovery_rate_limits! }

  context "on signup-session routes" do
    let(:recovery) { create_password_recovery_session! }

    before do
      get "/auth/email/availability",
        params: { email: "cross@example.com" },
        headers: { "Authorization" => "Recovery #{recovery['recoverySessionToken']}" }
    end

    it "does not accept a recovery token on signup-session routes" do
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "on authenticated routes" do
    let(:recovery) { create_password_recovery_session! }

    before do
      post "/auth/email-verification/send",
        headers: { "Authorization" => "Recovery #{recovery['recoverySessionToken']}" },
        as: :json
    end

    it "does not accept a recovery token on authenticated routes" do
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
