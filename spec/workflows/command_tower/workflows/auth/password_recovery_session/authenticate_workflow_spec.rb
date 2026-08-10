# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::PasswordRecoverySession::AuthenticateWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(request: request) }

    let(:recovery_token) { CommandTower::Services::Auth::PasswordRecoverySession::Create.call.data[:token] }

    context "without a recovery session token" do
      let(:request) { build_password_recovery_request }

      it "returns PasswordRecoverySessionMissingError" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unauthorized)
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::PasswordRecoverySessionMissingError)
        )
      end
    end

    context "with a Bearer scheme" do
      let(:request) { build_password_recovery_request(authorization: "Bearer sometoken") }

      it "returns PasswordRecoverySessionInvalidError" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unauthorized)
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError)
      end
    end

    context "with a Signup session token" do
      let(:request) do
        build_password_recovery_request(
          authorization: "Recovery #{CommandTower::Services::Auth::SignupSession::Create.call.data[:token]}"
        )
      end

      it "refuses to cross token families" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unauthorized)
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError)
      end
    end

    context "with a valid recovery token" do
      let(:request) { build_password_recovery_request(authorization: "Recovery #{recovery_token}") }

      it "returns the recovery session" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:password_recovery_session]).to be_a(CommandTower::Auth::PasswordRecoverySessionContext)
        expect(result.payload[:password_recovery_session].jti).to be_present
      end
    end
  end
end
