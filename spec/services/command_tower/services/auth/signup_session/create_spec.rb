# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::SignupSession::Create do
  describe ".call" do
    subject(:result) { described_class.call }

    it "returns a token, expiration, and jti" do
      expect(result).to be_success
      expect(result.data[:token]).to be_present
      expect(result.data[:expires_at]).to be_present
      expect(result.data[:jti]).to be_present
    end

    it "expires after the configured ttl" do
      expect(result.data[:expires_at]).to be_within(1.second)
        .of(CommandTower.config.signup_session.ttl.from_now.utc)
    end

    context "when Validate can decode the token" do
      subject(:validate_result) do
        CommandTower::Services::Auth::SignupSession::Validate.call(
          token: result.data[:token],
          client_ip: "127.0.0.1"
        )
      end

      it { expect(validate_result).to be_success }

      it "returns the same jti" do
        expect(validate_result.data[:signup_session].jti).to eq(result.data[:jti])
      end
    end

    context "when encoding fails" do
      before do
        allow(CommandTower::Services::Auth::SignupSession::Encode).to receive(:call).and_return(
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
