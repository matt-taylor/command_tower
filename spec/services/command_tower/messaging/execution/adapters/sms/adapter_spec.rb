# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::Adapters::Sms::Adapter do
  let(:build_request) do
    lambda do |to: "+14155552671", body: "Hello"|
      rendered = CommandTower::Messaging::Rendering::RenderedSmsPayload.build(
        recipient_address: to,
        body:,
      )
      CommandTower::Messaging::Execution::AdapterRequest.build(
        channel_delivery_id: 1,
        communication_id: 2,
        channel_key: "sms",
        attempt_id: 3,
        rendered:,
      )
    end
  end

  let(:configured_double) do
    instance_double(
      CommandTower::Messaging::Execution::Adapters::Sms::Configuration,
      sms_configured?: true,
      account_sid: "ACxxx",
      auth_token: "secret",
      use_messaging_service?: false,
      from_number: "+15551234567",
      messaging_service_sid: nil,
    )
  end

  context "when Twilio accepts the message with from number" do
    let(:http) { instance_double(CommandTower::Messaging::Execution::Adapters::Sms::TwilioHttpClient) }

    before do
      expect(http).to receive(:create_message).with(
        hash_including(to: "+14155552671", body: "Hello", from: "+15551234567", messaging_service_sid: nil),
      ).and_return(ok: true, status_code: 201, sid: "SMabc", provider_status: "queued", provider_error_code: nil)
    end

    subject(:result) do
      described_class.new(http_client: http, configuration: configured_double).call(request: build_request.call)
    end

    it "maps Twilio acceptance to success with provider sid and status" do
      expect(result.success?).to eq(true)
      expect(result.provider_message_id).to eq("SMabc")
      expect(result.normalized_provider_status).to eq("queued")
    end
  end

  context "when messaging_service_sid is configured" do
    let(:config) do
      instance_double(
        CommandTower::Messaging::Execution::Adapters::Sms::Configuration,
        sms_configured?: true,
        account_sid: "ACxxx",
        auth_token: "secret",
        use_messaging_service?: true,
        from_number: "+15551234567",
        messaging_service_sid: "MGxxx",
      )
    end
    let(:http) { instance_double(CommandTower::Messaging::Execution::Adapters::Sms::TwilioHttpClient) }

    before do
      expect(http).to receive(:create_message).with(
        hash_including(messaging_service_sid: "MGxxx", from: nil),
      ).and_return(ok: true, status_code: 201, sid: "SMabc", provider_status: "queued", provider_error_code: nil)
    end

    subject(:result) do
      described_class.new(http_client: http, configuration: config).call(request: build_request.call)
    end

    it "uses messaging_service_sid when configured" do
      expect(result.success?).to eq(true)
    end
  end

  context "when Twilio responds with an authentication failure" do
    let(:http) { instance_double(CommandTower::Messaging::Execution::Adapters::Sms::TwilioHttpClient) }

    before do
      allow(http).to receive(:create_message).and_return(
        ok: false, status_code: 401, sid: nil, provider_status: nil, provider_error_code: "20003",
      )
    end

    subject(:result) do
      described_class.new(http_client: http, configuration: configured_double).call(request: build_request.call)
    end

    it "maps authentication failures to twilio_auth_failed" do
      expect(result.terminal_failure?).to eq(true)
      expect(result.error_code).to eq("twilio_auth_failed")
    end
  end

  context "when Twilio rejects the message" do
    let(:http) { instance_double(CommandTower::Messaging::Execution::Adapters::Sms::TwilioHttpClient) }

    before do
      allow(http).to receive(:create_message).and_return(
        ok: false, status_code: 400, sid: nil, provider_status: nil, provider_error_code: "21211",
      )
    end

    subject(:result) do
      described_class.new(http_client: http, configuration: configured_double).call(request: build_request.call)
    end

    it "maps provider rejection to twilio_rejected" do
      expect(result.terminal_failure?).to eq(true)
      expect(result.error_code).to eq("twilio_rejected")
    end
  end

  context "when Twilio rate limits or errors transiently" do
    let(:http) { instance_double(CommandTower::Messaging::Execution::Adapters::Sms::TwilioHttpClient) }

    before do
      allow(http).to receive(:create_message).and_return(
        ok: false, status_code: 429, sid: nil, provider_status: nil, provider_error_code: nil,
      )
    end

    subject(:result) do
      described_class.new(http_client: http, configuration: configured_double).call(request: build_request.call)
    end

    it "maps rate limits and 5xx to twilio_transient" do
      expect(result.retryable_failure?).to eq(true)
      expect(result.error_code).to eq("twilio_transient")
    end
  end

  context "when the network call times out" do
    let(:http) { instance_double(CommandTower::Messaging::Execution::Adapters::Sms::TwilioHttpClient) }

    before { allow(http).to receive(:create_message).and_raise(Net::ReadTimeout) }

    subject(:result) do
      described_class.new(http_client: http, configuration: configured_double).call(request: build_request.call)
    end

    it "maps network timeouts to twilio_transient" do
      expect(result.retryable_failure?).to eq(true)
      expect(result.error_code).to eq("twilio_transient")
    end
  end

  context "when recipient is not E.164" do
    let(:http) { instance_double(CommandTower::Messaging::Execution::Adapters::Sms::TwilioHttpClient) }

    before { expect(http).not_to receive(:create_message) }

    subject(:result) do
      described_class.new(http_client: http, configuration: configured_double).call(
        request: build_request.call(to: "4155552671"),
      )
    end

    it "rejects non-E.164 recipients as invalid_recipient" do
      expect(result.terminal_failure?).to eq(true)
      expect(result.error_code).to eq("invalid_recipient")
    end
  end

  context "when Twilio accepts the message successfully" do
    let(:http) { instance_double(CommandTower::Messaging::Execution::Adapters::Sms::TwilioHttpClient) }

    before do
      allow(http).to receive(:create_message).and_return(
        ok: true, status_code: 201, sid: "SMabc", provider_status: "queued", provider_error_code: nil,
      )
    end

    subject(:result) do
      described_class.new(http_client: http, configuration: configured_double).call(request: build_request.call)
    end

    it "does not leak raw provider objects outside AdapterResult" do
      expect(result).to be_a(CommandTower::Messaging::Execution::AdapterResult)
      expect(result.members).to eq(%i[outcome normalized_provider_status provider_message_id error_code])
    end
  end
end
