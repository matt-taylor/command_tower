# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::SignupSession::Decode do
  describe ".call" do
    subject(:result) { described_class.call(token: token) }

    let(:config) { CommandTower.config.signup_session }
    let(:jti) { SecureRandom.uuid }
    let(:expires_at) { 20.minutes.from_now.utc }
    let(:token) { build_token.call }

    let(:build_token) do
      lambda do |**overrides|
        payload = {
          iss: overrides.fetch(:iss, config.issuer),
          aud: overrides.fetch(:aud, config.audience),
          purpose: overrides.fetch(:purpose, config.purpose),
          jti: overrides.fetch(:jti, jti),
          iat: Time.now.to_i,
          exp: overrides.fetch(:exp, expires_at.to_i)
        }
        JWT.encode(payload, config.jwt_secret, "HS256")
      end
    end

    it "returns the decoded payload" do
      expect(result).to be_success
      expect(result.data[:payload][:jti]).to eq(jti)
      expect(result.data[:payload][:iss]).to eq(config.issuer)
      expect(result.data[:payload][:aud]).to eq(config.audience)
      expect(result.data[:payload][:purpose]).to eq(config.purpose)
    end

    context "with an expired token" do
      let(:token) { build_token.call(exp: 1.minute.ago.utc.to_i) }

      it "returns SignupSessionExpiredError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::SignupSessionExpiredError)
        )
      end
    end

    context "with a malformed token" do
      let(:token) { "not-a-valid-jwt" }

      it "returns SignupSessionInvalidError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::SignupSessionInvalidError)
        )
      end
    end

    context "with a token signed by a different secret" do
      let(:token) do
        JWT.encode({ jti: jti, exp: expires_at.to_i }, "some-other-secret", "HS256")
      end

      it "returns SignupSessionInvalidError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::SignupSessionInvalidError)
        )
      end
    end

    context "when token is missing" do
      let(:token) { nil }

      it "returns a ValidationError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError))
      end
    end
  end
end
