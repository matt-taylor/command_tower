# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::LogoutWorkflow do
  describe ".call" do
    subject(:result) { described_class.call }

    it "returns logged_out with clear_token" do
      expect(result).to be_success
      expect(result.http_status).to eq(:ok)
      expect(result.payload).to eq(message: "logged_out")
      expect(result.response_effects).to eq(clear_token: true)
    end

    it "does not persist session_cleared without a resolvable token" do
      expect { result }.not_to change { CommandTower::Audit::Event.where(action: "session_cleared").count }
    end

    context "when a valid token is supplied and session_cleared is enabled" do
      let(:user) { create(:user) }
      let(:token) { login_token_for(user) }

      subject(:result) { described_class.call(token:) }

      before { CommandTower.config.registry.audit.set_enabled!(:session_cleared, true) }

      it "persists session_cleared for the resolved user" do
        expect { result }.to change { CommandTower::Audit::Event.where(action: "session_cleared").count }.by(1)
      end

      context "when inspecting the session_cleared row" do
        before { result }

        let(:row) { CommandTower::Audit::Event.find_by!(action: "session_cleared") }

        it "records the resolved user" do
          expect(row.affected_user_id).to eq(user.id)
        end
      end
    end

    context "when the token carries an impersonation overlay" do
      let(:user) { create(:user) }
      let(:target) { create(:user) }
      let!(:session) { create(:impersonation_session, actor: user, target:) }
      let(:token) { impersonation_token_for(user, session) }

      subject(:result) { described_class.call(token:) }

      it "ends only that impersonation session" do
        expect(result).to be_success
        expect(session.reload.end_reason).to eq("logout")
      end
    end

    context "when a valid token is supplied and session_cleared stays default-off" do
      let(:user) { create(:user) }
      let(:token) { login_token_for(user) }

      subject(:result) { described_class.call(token:) }

      it "does not persist session_cleared" do
        expect { result }.not_to change { CommandTower::Audit::Event.where(action: "session_cleared").count }
      end
    end
  end
end
