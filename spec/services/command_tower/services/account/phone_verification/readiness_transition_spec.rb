# frozen_string_literal: true

RSpec.describe "phone verification readiness transition" do
  let(:for_channel) do
    lambda do |key, user:, platform_enabled_channels:|
      CommandTower::Messaging::RecipientReadiness.for_channel(
        recipient_id: user.id,
        channel_key: key,
        platform_enabled_channels:
      )
    end
  end

  let(:user) { create(:user, :without_phone) }
  let(:platform_enabled_channels) { ["sms"] }

  before do
    CommandTower::Identity::PhoneVerification::SmsTransport.reset_adapter!
    CommandTower::Identity::PhoneVerification::SmsTransport::Adapters::FakeAdapter.reset!
    allow(CommandTower.config.identity.phone_verification).to receive(:sms_adapter).and_return("fake")
    allow(CommandTower.config.identity.phone_verification).to receive(:resend_cooldown).and_return(0.seconds)
  end

  it "clears identity_unverified after successful phone verification" do
    CommandTower::Services::Account::UpdatePhone.call(user:, phone_number: "+14155552671")
    user.reload

    before = for_channel.call("sms", user:, platform_enabled_channels:)
    expect(before.reason_codes).to include("identity_unverified")

    send_result = CommandTower::Services::Account::PhoneVerification::Send.call(user:)
    expect(send_result).to be_success
    code = UserSecret.find_by!(user:, reason: CommandTower::Secrets::PHONE_VERIFICATION).secret

    verify_result = CommandTower::Services::Account::PhoneVerification::Verify.call(user:, code:)
    expect(verify_result).to be_success
    user.reload

    after = for_channel.call("sms", user:, platform_enabled_channels:)
    expect(after.reason_codes).not_to include("identity_unverified")
    expect(after.reason_codes).not_to include("identity_missing")
  end
end
