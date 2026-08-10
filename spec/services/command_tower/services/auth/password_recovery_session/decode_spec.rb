# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PasswordRecoverySession::Decode do
  describe ".call" do
    subject(:result) { described_class.call(token: token) }

    let(:config) { CommandTower.config.password_recovery_session }

    context "with a token this engine issued" do
      let(:token) do
        CommandTower::Services::Auth::PasswordRecoverySession::Encode.call(
          jti: "jti-1",
          expires_at: 15.minutes.from_now.utc
        ).data[:token]
      end

      it { expect(result).to be_success }
      it { expect(result.data[:payload][:jti]).to eq("jti-1") }
    end

    context "with an unparseable token" do
      let(:token) { "not-a-jwt" }

      it "returns PasswordRecoverySessionInvalidError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError)
        )
      end
    end

    context "with a token signed by a different secret" do
      let(:token) { JWT.encode({ jti: "jti-1", exp: 15.minutes.from_now.to_i }, "some-other-secret", "HS256") }

      it "returns PasswordRecoverySessionInvalidError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError)
      end
    end

    context "with an expired signature" do
      let(:token) { JWT.encode({ jti: "jti-1", exp: 5.minutes.ago.to_i }, config.jwt_secret, "HS256") }

      it "returns PasswordRecoverySessionExpiredError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::PasswordRecoverySessionExpiredError)
        )
      end
    end
  end
end
