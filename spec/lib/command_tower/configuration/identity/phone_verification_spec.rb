# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::Identity::PhoneVerification do
  around do |example|
    previous = CommandTower.config.identity.phone_verification.sms_adapter
    example.run
  ensure
    CommandTower.config.identity.phone_verification.sms_adapter = previous
  end

  it "accepts the same adapter set as the Messaging SMS validation style (without disabled)" do
    expect(described_class::ADAPTERS).to eq(%w[fake log twilio])

    %w[fake log twilio].each do |name|
      expect {
        CommandTower.config.identity.phone_verification.sms_adapter = name
      }.not_to raise_error
      expect(CommandTower.config.identity.phone_verification.sms_adapter).to eq(name)
    end
  end

  it "rejects unknown sms_adapter values at configure time" do
    expect {
      CommandTower.config.identity.phone_verification.sms_adapter = "disabled"
    }.to raise_error(ClassComposer::ValidatorError, /Allowed: fake, log, twilio/)
  end
end
