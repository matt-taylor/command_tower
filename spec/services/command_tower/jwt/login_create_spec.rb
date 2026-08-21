# frozen_string_literal: true

RSpec.describe CommandTower::Jwt::LoginCreate do
  let(:user) { create(:user) }

  describe ".call" do
    subject(:call) { described_class.(user:) }

    it do
      expect(call.token).to be_a String
    end

    it "issues a token carrying the user identity" do
      expect(CommandTower::Jwt::Decode.(token: call.token).payload[:user_id]).to eq(user.id)
    end

    it "sets verifier token" do
      expect(user.verifier_token).to be_nil
      call
      expect(user.reload.verifier_token).to be_present
    end

    context "when verify token is present" do
      let(:user) { create(:user, :verifier_token) }

      it do
        expect(call.token).to be_a String
      end
    end

    context "when an impersonation session id is supplied" do
      subject(:call) { described_class.call(user:, impersonation_session_id: session.id) }

      let(:session) { create(:impersonation_session, actor: user, target: create(:user)) }

      it "embeds the overlay claim without changing user_id" do
        expect(CommandTower::Jwt::Decode.call(token: call.token).payload[:user_id]).to eq(user.id)
        expect(CommandTower::Jwt::Decode.call(token: call.token).payload[:impersonation_session_id]).to eq(session.id)
      end
    end
  end
end
