# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Impersonation::StopWorkflow do
  describe ".call" do
    subject(:result) do
      described_class.call(actor:, impersonation_session_id: session.id)
    end

    let(:actor) { create(:user, :role_impersonation_operator) }
    let(:target) { create(:user, roles: ["member"]) }
    let!(:session) { create(:impersonation_session, actor:, target:) }

    before do
      CommandTower::Current.user_id = actor.id
      CommandTower::Current.effective_user_id = actor.id
    end

    after { CommandTower::Current.reset }

    it { expect(result).to be_success }

    it { expect(result.http_status).to eq(:ok) }

    context "when inspecting the replacement token" do
      subject(:payload) do
        CommandTower::Jwt::Decode.call(token: result.response_effects[:set_token][:token]).payload
      end

      it "re-issues an administrator JWT without the overlay claim" do
        expect(payload[:user_id]).to eq(actor.id)
        expect(payload[:impersonation_session_id]).to be_nil
      end
    end

    it "ends the session as manual" do
      result
      expect(session.reload.end_reason).to eq("manual")
    end

    it "emits impersonation_ended once" do
      expect { result }.to change { CommandTower::Audit::Event.where(action: "impersonation_ended").count }.by(1)
    end

    context "when the session is already ended" do
      let!(:session) { create(:impersonation_session, :ended, actor:, target:) }

      it { expect(result).to be_success }

      it "does not emit a second impersonation_ended" do
        expect { result }.not_to change { CommandTower::Audit::Event.where(action: "impersonation_ended").count }
      end
    end

    context "when no session id is supplied" do
      subject(:result) { described_class.call(actor:, impersonation_session_id: nil) }

      it "fails as missing" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unprocessable_entity)
      end
    end
  end
end
