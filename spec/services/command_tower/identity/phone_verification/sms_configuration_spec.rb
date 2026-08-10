# frozen_string_literal: true

RSpec.describe CommandTower::Identity::PhoneVerification::SmsConfiguration do
  let(:with_phone_verification) do
    lambda do |enable:, sms_adapter:, sms_from: nil, &block|
      config = CommandTower.config.identity.phone_verification
      previous = {
        enable: config.enable,
        sms_adapter: config.sms_adapter,
        sms_from: config.sms_from
      }
      config.enable = enable
      config.sms_adapter = sms_adapter
      config.sms_from = sms_from
      block.call
    ensure
      config.enable = previous[:enable]
      config.sms_adapter = previous[:sms_adapter]
      config.sms_from = previous[:sms_from]
    end
  end

  it "is not ready when phone verification is disabled" do
    with_phone_verification.call(enable: false, sms_adapter: "fake") do
      expect(described_class.sms_ready?).to eq(false)
    end
  end

  context "when running in a test environment" do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))
    end

    it "is ready for fake adapter outside production" do
      with_phone_verification.call(enable: true, sms_adapter: "fake") do
        expect(described_class.sms_ready?).to eq(true)
      end
    end
  end

  context "when running in a development environment" do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
    end

    it "is ready for log adapter outside production" do
      with_phone_verification.call(enable: true, sms_adapter: "log") do
        expect(described_class.sms_ready?).to eq(true)
      end
    end
  end

  context "when running in a production environment" do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    end

    it "is not ready for fake adapter in production" do
      with_phone_verification.call(enable: true, sms_adapter: "fake") do
        expect(described_class.sms_ready?).to eq(false)
      end
    end
  end

  it "is ready for twilio when credentials and from are present" do
    with_phone_verification.call(enable: true, sms_adapter: "twilio", sms_from: "+15551234567") do
      with_env(
        "TWILIO_ACCOUNT_SID" => "ACxxx",
        "TWILIO_AUTH_TOKEN" => "secret"
      ) do
        expect(described_class.sms_ready?).to eq(true)
      end
    end
  end

  it "is ready for twilio when from comes from TWILIO_FROM" do
    with_phone_verification.call(enable: true, sms_adapter: "twilio", sms_from: nil) do
      with_env(
        "TWILIO_ACCOUNT_SID" => "ACxxx",
        "TWILIO_AUTH_TOKEN" => "secret",
        "TWILIO_FROM" => "+15551234567",
        "TWILIO_FROM_NUMBER" => nil
      ) do
        expect(described_class.sms_ready?).to eq(true)
      end
    end
  end

  it "is ready for twilio when from comes from TWILIO_FROM_NUMBER" do
    with_phone_verification.call(enable: true, sms_adapter: "twilio", sms_from: nil) do
      with_env(
        "TWILIO_ACCOUNT_SID" => "ACxxx",
        "TWILIO_AUTH_TOKEN" => "secret",
        "TWILIO_FROM" => nil,
        "TWILIO_FROM_NUMBER" => "+15551234567"
      ) do
        expect(described_class.sms_ready?).to eq(true)
      end
    end
  end

  it "is not ready for twilio when credentials are incomplete" do
    with_phone_verification.call(enable: true, sms_adapter: "twilio", sms_from: "+15551234567") do
      with_env(
        "TWILIO_ACCOUNT_SID" => "ACxxx",
        "TWILIO_AUTH_TOKEN" => nil,
        "TWILIO_FROM" => nil
      ) do
        expect(described_class.sms_ready?).to eq(false)
      end
    end
  end

  context "when rejecting unknown adapters at configure time" do
    let(:config) { CommandTower.config.identity.phone_verification }
    let(:previous) { config.sms_adapter }

    after { config.sms_adapter = previous }

    it "raises like Messaging SMS validation" do
      expect {
        config.sms_adapter = "unknown"
      }.to raise_error(ClassComposer::ValidatorError, /Allowed: fake, log, twilio/)
    end
  end
end
