# frozen_string_literal: true

RSpec.describe CommandTower::Jwt::LoginCreate do
  let(:user) { create(:user) }

  describe ".call" do
    subject(:call) { described_class.(user:) }

    it do
      expect(call.success?).to eq true
    end

    it do
      expect(call.token).to be_a String
    end

    it "sets verifier token" do
      expect(user.verifier_token).to be_nil
      call
      expect(user.reload.verifier_token).to be_present
    end

    context "when verify token is present" do
      let(:user) { create(:user, :verifier_token) }

      it do
        expect(call.success?).to eq true
      end

      it do
        expect(call.token).to be_a String
      end
    end
  end
end
