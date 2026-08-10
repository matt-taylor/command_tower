# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::SessionErrorStatus do
  describe ".http_status_for" do
    subject(:status) { described_class.http_status_for(error) }

    {
      CommandTower::Errors::Auth::EmailVerificationRequiredError => :precondition_failed,
      CommandTower::Errors::Auth::CsrfMissingError => :forbidden,
      CommandTower::Errors::Auth::CsrfMismatchError => :forbidden,
      CommandTower::Errors::ForbiddenError => :forbidden,
      CommandTower::Errors::Auth::InvalidCredentialsError => :unauthorized,
      CommandTower::Errors::UnauthorizedError => :unauthorized,
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
