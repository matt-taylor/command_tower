# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::SignupSession::Validate do
  describe ".call" do
    subject(:result) { described_class.call(token: token, client_ip: client_ip) }

    let(:config) { CommandTower.config.signup_session }
    let(:client_ip) { "127.0.0.1" }
    let(:token) { build_token.call }

    let(:build_token) do
      lambda do |**overrides|
        jti = overrides.delete(:jti) { SecureRandom.uuid }
        expires_at = overrides.delete(:expires_at) { config.ttl.from_now.utc }
        payload = {
          iss: overrides.fetch(:iss, config.issuer),
          aud: overrides.fetch(:aud, config.audience),
          purpose: overrides.fetch(:purpose, config.purpose),
          jti: jti,
          iat: Time.now.to_i,
          exp: expires_at.to_i
        }
        JWT.encode(payload, config.jwt_secret, "HS256")
      end
    end

    it "returns a signup session context bound to the calling ip" do
      expect(result).to be_success
      expect(result.data[:signup_session]).to be_a(CommandTower::Auth::SignupSessionContext)
      expect(result.data[:signup_session].jti).to be_present
      expect(result.data[:signup_session].client_ip).to eq(client_ip)
    end

    context "with an expired token" do
      let(:token) { build_token.call(expires_at: 1.minute.ago.utc) }

      it "returns SignupSessionExpiredError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::SignupSessionExpiredError)
      end
    end

    context "with the wrong audience" do
      let(:token) { build_token.call(aud: "wrong-audience") }

      it "returns SignupSessionInvalidError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::SignupSessionInvalidError)
      end
    end

    context "with the wrong issuer" do
      let(:token) { build_token.call(iss: "wrong-issuer") }

      it "returns SignupSessionInvalidError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::SignupSessionInvalidError)
      end
    end

    context "with the wrong purpose" do
      let(:token) { build_token.call(purpose: "password-recovery") }

      it "returns SignupSessionInvalidError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::SignupSessionInvalidError)
      end
    end

    context "with a blank jti" do
      let(:token) { build_token.call(jti: "") }

      it "returns SignupSessionInvalidError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::SignupSessionInvalidError)
      end
    end
  end
end
