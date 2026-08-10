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
  end
end
