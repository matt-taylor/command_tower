# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::PasswordReset::ValidateResponseSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(valid: true, expires_at: expires_at) }

    context "with a Time expiry" do
      let(:expires_at) { Time.utc(2026, 7, 14, 4, 46, 14) }

      it { expect(payload).to eq(valid: true, expiresAt: expires_at.iso8601) }
    end

    context "with a stringified expiry" do
      let(:expires_at) { "2026-07-14 04:46:14 UTC" }

      it { expect(payload[:expiresAt]).to eq("2026-07-14 04:46:14 UTC") }
    end

    context "without an expiry" do
      let(:expires_at) { nil }

      it "omits expiresAt entirely" do
        expect(payload).to eq(valid: true)
      end
    end
  end
end
