# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PasswordRecoverySession::Validate do
  describe ".call" do
    subject(:result) { described_class.call(token: token, client_ip: "203.0.113.7") }

    let(:config) { CommandTower.config.password_recovery_session }

    let(:encode) { ->(payload) { JWT.encode(payload, config.jwt_secret, "HS256") } }

    let(:claims) do
      lambda do |overrides = {}|
        {
          iss: config.issuer,
          aud: config.audience,
          purpose: config.purpose,
          jti: "jti-1",
          iat: Time.now.to_i,
          exp: 15.minutes.from_now.to_i
        }.merge(overrides)
      end
    end

    context "with a well formed session token" do
      let(:token) { encode.call(claims.call) }

      subject(:session) { result.data[:password_recovery_session] }

      it { expect(result).to be_success }

      it "returns the typed recovery session" do
        expect(session).to be_a(CommandTower::Auth::PasswordRecoverySessionContext)
        expect(session.jti).to eq("jti-1")
        expect(session.client_ip).to eq("203.0.113.7")
      end
    end

    context "with a foreign issuer" do
      let(:token) { encode.call(claims.call(iss: "someone-else")) }

      it { expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError) }
    end

    context "with a foreign audience" do
      let(:token) { encode.call(claims.call(aud: "signup-availability")) }

      it { expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError) }
    end

    context "with a foreign purpose" do
      let(:token) { encode.call(claims.call(purpose: "signup")) }

      it { expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError) }
    end

    context "without a jti" do
      let(:token) { encode.call(claims.call(jti: nil)) }

      it { expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError) }
    end

    context "with a signup session token" do
      let(:token) { CommandTower::Services::Auth::SignupSession::Create.call.data[:token] }

      it "rejects it rather than crossing token families" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError)
      end
    end

    context "with an expired token" do
      let(:token) { encode.call(claims.call(exp: 5.minutes.ago.to_i)) }

      it { expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoverySessionExpiredError) }
    end
  end
end
