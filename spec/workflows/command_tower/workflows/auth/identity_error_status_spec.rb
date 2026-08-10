# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::IdentityErrorStatus do
  describe ".http_status_for" do
    subject(:status) { described_class.http_status_for(error) }

    {
      CommandTower::Errors::Auth::PasswordRecoverySessionMissingError => :unauthorized,
      CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError => :unauthorized,
      CommandTower::Errors::Auth::PasswordRecoverySessionExpiredError => :unauthorized,
      CommandTower::Errors::Auth::PasswordResetInvalidTokenError => :unauthorized,
      CommandTower::Errors::Auth::PasswordRecoverySessionRateLimitError => :too_many_requests,
      CommandTower::Errors::Auth::PasswordRecoveryIpRateLimitError => :too_many_requests,
      CommandTower::Errors::Auth::VerificationCodeInvalidError => :unprocessable_entity,
      CommandTower::Errors::ValidationError => :unprocessable_entity,
      CommandTower::Errors::Auth::PasswordResetUnavailableError => :service_unavailable,
      CommandTower::Errors::Auth::VerificationSendFailedError => :bad_gateway,
      CommandTower::Errors::InternalError => :internal_server_error
    }.each do |error_class, expected|
      context "with #{error_class}" do
        let(:error) { error_class.new }

        it { is_expected.to eq(expected) }
      end
    end

    context "with an unmapped error" do
      let(:error) { CommandTower::Errors::NotFoundError.new }

      it { is_expected.to eq(:internal_server_error) }
    end
  end
end
