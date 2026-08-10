# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::SignupErrorStatus do
  describe ".http_status_for" do
    subject(:status) { described_class.http_status_for(error) }

    {
      CommandTower::Errors::Auth::SignupSessionMissingError => :unauthorized,
      CommandTower::Errors::Auth::SignupSessionInvalidError => :unauthorized,
      CommandTower::Errors::Auth::SignupSessionExpiredError => :unauthorized,
      CommandTower::Errors::Auth::SignupSessionRateLimitError => :too_many_requests,
      CommandTower::Errors::Auth::SignupIpRateLimitError => :too_many_requests,
      CommandTower::Errors::Auth::EmailAlreadyRegisteredError => :unprocessable_entity,
      CommandTower::Errors::ValidationError => :unprocessable_entity,
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
