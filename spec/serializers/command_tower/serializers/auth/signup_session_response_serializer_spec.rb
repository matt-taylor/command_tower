# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::SignupSessionResponseSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(token: token, expires_at: expires_at) }

    let(:token) { "signup-token" }
    let(:expires_at) { 1.hour.from_now }

    it "builds the signup session shape" do
      expect(payload).to eq(
        signupSessionToken: "signup-token",
        expiresAt: expires_at.iso8601
      )
    end
  end
end
