# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::ErrorMapping do
  describe ".http_status_for" do
    {
      CommandTower::Errors::Account::PhoneMissingError => :unprocessable_entity,
      CommandTower::Errors::Account::PhoneAlreadyVerifiedError => :unprocessable_entity,
      CommandTower::Errors::Account::PhoneVerificationCodeInvalidError => :unprocessable_entity,
      CommandTower::Errors::Account::PhoneVerificationExpiredError => :unprocessable_entity,
      CommandTower::Errors::Account::PhoneVerificationStaleError => :unprocessable_entity,
      CommandTower::Errors::Account::PhoneVerificationThrottledError => :too_many_requests,
      CommandTower::Errors::Account::SmsCapabilityUnavailableError => :service_unavailable,
      CommandTower::Errors::Account::PhoneVerificationSendFailedError => :bad_gateway,
      CommandTower::Errors::Account::PushoverCapabilityUnavailableError => :service_unavailable,
      CommandTower::Errors::Account::PushoverNotConfiguredError => :unprocessable_entity,
      CommandTower::Errors::Account::PushoverAlreadyConfiguredError => :unprocessable_entity,
      CommandTower::Errors::Account::PushoverProviderUnavailableError => :bad_gateway,
    }.each do |error_class, status|
      it "maps #{error_class.name} to #{status}" do
        expect(described_class.http_status_for(error_class.new)).to eq(status)
      end
    end

    it "maps PushoverVerificationFailedError to unprocessable_entity" do
      expect(
        described_class.http_status_for(
          CommandTower::Errors::Account::PushoverVerificationFailedError.new(code: "pushover_invalid_user")
        )
      ).to eq(:unprocessable_entity)
    end
  end
end
