# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::SignupSession::Encode do
  describe ".call" do
    subject(:result) { described_class.call(jti: jti, expires_at: expires_at) }

    let(:config) { CommandTower.config.signup_session }
    let(:jti) { SecureRandom.uuid }
    let(:expires_at) { 20.minutes.from_now.utc }

    it "returns a token" do
      expect(result).to be_success
      expect(result.data[:token]).to be_present
    end

    context "with encoded claims" do
      subject(:decoded) do
        JWT.decode(result.data[:token], config.jwt_secret, true, { algorithm: "HS256" }).first
      end

      it "includes the signup contract claims" do
        expect(decoded["iss"]).to eq(config.issuer)
        expect(decoded["aud"]).to eq(config.audience)
        expect(decoded["purpose"]).to eq(config.purpose)
        expect(decoded["jti"]).to eq(jti)
        expect(decoded["exp"]).to eq(expires_at.to_i)
      end
    end

    context "when jti is missing" do
      let(:jti) { nil }

      it "returns a ValidationError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError))
      end
    end

    context "when expires_at is not a Time" do
      let(:expires_at) { "not-a-time" }

      it "returns a ValidationError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError))
      end
    end
  end
end
