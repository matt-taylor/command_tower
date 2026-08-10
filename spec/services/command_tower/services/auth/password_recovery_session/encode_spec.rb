# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PasswordRecoverySession::Encode do
  describe ".call" do
    subject(:result) { described_class.call(jti: "jti-1", expires_at: expires_at) }

    let(:expires_at) { 15.minutes.from_now.utc }
    let(:config) { CommandTower.config.password_recovery_session }

    it { expect(result).to be_success }

    it "stamps the configured claims" do
      payload, = JWT.decode(result.data[:token], config.jwt_secret, true, { algorithm: "HS256" })

      expect(payload).to include(
        "iss" => config.issuer,
        "aud" => config.audience,
        "purpose" => config.purpose,
        "jti" => "jti-1",
        "exp" => expires_at.to_i
      )
    end

    context "without a jti" do
      subject(:result) { described_class.call(expires_at: expires_at) }

      it { expect(result).to be_failure }
    end
  end
end
