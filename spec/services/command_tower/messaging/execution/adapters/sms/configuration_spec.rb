# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::Adapters::Sms::Configuration do
  let(:with_sms_config) do
    lambda do |adapter:, from_number: nil, messaging_service_sid: nil, &block|
      sms = CommandTower.config.messaging.sms
      previous = {
        adapter: sms.adapter,
        from_number: sms.from_number,
        messaging_service_sid: sms.messaging_service_sid,
      }
      sms.adapter = adapter
      sms.from_number = from_number
      sms.messaging_service_sid = messaging_service_sid
      block.call
    ensure
      sms.adapter = previous[:adapter]
      sms.from_number = previous[:from_number]
      sms.messaging_service_sid = previous[:messaging_service_sid]
    end
  end

  it "is not configured when adapter is disabled (default)" do
    with_sms_config.call(adapter: "disabled", from_number: "+15551234567") do
      with_env(
        "TWILIO_ACCOUNT_SID" => "ACxxx",
        "TWILIO_AUTH_TOKEN" => "secret",
      ) do
        expect(described_class.sms_configured?).to eq(false)
      end
    end
  end

  it "is not configured when adapter is fake" do
    with_sms_config.call(adapter: "fake", from_number: "+15551234567") do
      with_env(
        "TWILIO_ACCOUNT_SID" => "ACxxx",
        "TWILIO_AUTH_TOKEN" => "secret",
      ) do
        expect(described_class.sms_configured?).to eq(false)
      end
    end
  end

  it "is not configured when adapter is log" do
    with_sms_config.call(adapter: "log", from_number: "+15551234567") do
      with_env(
        "TWILIO_ACCOUNT_SID" => "ACxxx",
        "TWILIO_AUTH_TOKEN" => "secret",
      ) do
        expect(described_class.sms_configured?).to eq(false)
      end
    end
  end

  it "is not configured when twilio is missing account sid" do
    with_sms_config.call(adapter: "twilio", from_number: "+15551234567") do
      with_env(
        "TWILIO_ACCOUNT_SID" => nil,
        "TWILIO_AUTH_TOKEN" => "secret",
      ) do
        expect(described_class.sms_configured?).to eq(false)
      end
    end
  end

  it "is not configured when twilio is missing auth token" do
    with_sms_config.call(adapter: "twilio", from_number: "+15551234567") do
      with_env(
        "TWILIO_ACCOUNT_SID" => "ACxxx",
        "TWILIO_AUTH_TOKEN" => nil,
      ) do
        expect(described_class.sms_configured?).to eq(false)
      end
    end
  end

  it "is not configured when twilio has no sender identity" do
    with_sms_config.call(adapter: "twilio", from_number: nil, messaging_service_sid: nil) do
      with_env(
        "TWILIO_ACCOUNT_SID" => "ACxxx",
        "TWILIO_AUTH_TOKEN" => "secret",
        "TWILIO_FROM" => nil,
      ) do
        expect(described_class.sms_configured?).to eq(false)
      end
    end
  end

  it "is configured when twilio has credentials and from_number" do
    with_sms_config.call(adapter: "twilio", from_number: "+15551234567") do
      with_env(
        "TWILIO_ACCOUNT_SID" => "ACxxx",
        "TWILIO_AUTH_TOKEN" => "secret",
      ) do
        expect(described_class.sms_configured?).to eq(true)
      end
    end
  end

  it "is configured when twilio has credentials and messaging_service_sid" do
    with_sms_config.call(adapter: "twilio", from_number: nil, messaging_service_sid: "MGxxx") do
      with_env(
        "TWILIO_ACCOUNT_SID" => "ACxxx",
        "TWILIO_AUTH_TOKEN" => "secret",
        "TWILIO_FROM" => nil,
      ) do
        expect(described_class.sms_configured?).to eq(true)
        expect(described_class.new.use_messaging_service?).to eq(true)
      end
    end
  end

  context "when both sender mechanisms are set" do
    subject(:config) { described_class.new }

    around do |example|
      with_sms_config.call(adapter: "twilio", from_number: "+15551234567", messaging_service_sid: "MGxxx") do
        with_env(
          "TWILIO_ACCOUNT_SID" => "ACxxx",
          "TWILIO_AUTH_TOKEN" => "secret",
        ) { example.run }
      end
    end

    it "prefers messaging_service_sid" do
      expect(config.use_messaging_service?).to eq(true)
      expect(config.messaging_service_sid).to eq("MGxxx")
    end
  end

  it "falls back to TWILIO_FROM when from_number is blank" do
    with_sms_config.call(adapter: "twilio", from_number: nil) do
      with_env(
        "TWILIO_ACCOUNT_SID" => "ACxxx",
        "TWILIO_AUTH_TOKEN" => "secret",
        "TWILIO_FROM" => "+15557654321",
      ) do
        expect(described_class.sms_configured?).to eq(true)
        expect(described_class.new.from_number).to eq("+15557654321")
      end
    end
  end
end
