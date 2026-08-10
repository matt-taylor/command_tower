# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::PasswordRecoverySessionResponseSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(token: "recovery-token", expires_at: expires_at) }

    let(:expires_at) { Time.utc(2026, 7, 14, 4, 46, 14) }

    it { expect(payload[:recoverySessionToken]).to eq("recovery-token") }
    it { expect(payload[:expiresAt]).to eq(expires_at.iso8601) }
    it { expect(payload.keys).to contain_exactly(:recoverySessionToken, :expiresAt) }
  end
end
