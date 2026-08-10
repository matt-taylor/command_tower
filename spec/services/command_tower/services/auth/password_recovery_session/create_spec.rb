# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PasswordRecoverySession::Create do
  describe ".call" do
    subject(:result) { described_class.call }

    it { expect(result).to be_success }

    it "mints a unique jti" do
      expect(result.data[:jti]).to be_present
      expect(result.data[:jti]).not_to eq(described_class.call.data[:jti])
    end

    it "expires after the configured ttl" do
      expect(result.data[:expires_at]).to be_within(1.second).of(
        CommandTower.config.password_recovery_session.ttl.from_now.utc
      )
    end

    context "when the validator accepts the minted token" do
      subject(:validated) do
        CommandTower::Services::Auth::PasswordRecoverySession::Validate.call(
          token: result.data[:token],
          client_ip: "127.0.0.1"
        )
      end

      it { expect(validated).to be_success }

      it "returns the same jti" do
        expect(validated.data[:password_recovery_session].jti).to eq(result.data[:jti])
      end
    end

    context "when encoding fails" do
      before do
        allow(CommandTower::Services::Auth::PasswordRecoverySession::Encode).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(errors: [CommandTower::Errors::InternalError.new])
        )
      end

      it "returns InternalError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::InternalError))
      end
    end
  end
end
