# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::Adapters::Email::Adapter do
  let(:build_request) do
    rendered = CommandTower::Messaging::Rendering::RenderedPayload.build(
      recipient_address: "user@example.com",
      subject: "Hello",
      text_body: "Plain",
      html_body: "<p>HTML</p>",
    )
    CommandTower::Messaging::Execution::AdapterRequest.build(
      channel_delivery_id: 1,
      communication_id: 2,
      channel_key: "email",
      attempt_id: 3,
      rendered:,
    )
  end

  context "with ActionMailer :test delivery" do
    before { ActionMailer::Base.deliveries.clear }

    subject(:result) { described_class.new.call(request: build_request) }

    it "returns success for ActionMailer :test delivery" do
      expect(result).to be_a(CommandTower::Messaging::Execution::AdapterResult)
      expect(result.outcome).to eq(:success)
      expect(result.normalized_provider_status).to eq("accepted")
      expect(ActionMailer::Base.deliveries.size).to eq(1)
    end
  end

  context "when the transport raises a transient error" do
    before do
      allow(CommandTower::Messaging::ChannelMailer).to receive(:deliver_rendered).and_raise(Net::OpenTimeout)
    end

    subject(:result) { described_class.new.call(request: build_request) }

    it "maps transient transport errors to retryable_failure" do
      expect(result.outcome).to eq(:retryable_failure)
      expect(result.error_code).to eq("smtp_transient")
    end
  end

  context "when the transport raises a permanent SMTP error" do
    before do
      allow(CommandTower::Messaging::ChannelMailer).to receive(:deliver_rendered).and_raise(
        Net::SMTPAuthenticationError.new("535"),
      )
    end

    subject(:result) { described_class.new.call(request: build_request) }

    it "maps permanent SMTP errors to terminal_failure" do
      expect(result.outcome).to eq(:terminal_failure)
      expect(result.error_code).to eq("smtp_rejected")
    end
  end

  context "when the transport raises an unexpected error" do
    before do
      allow(CommandTower::Messaging::ChannelMailer).to receive(:deliver_rendered).and_raise(RuntimeError, "secret")
    end

    subject(:result) { described_class.new.call(request: build_request) }

    it "never raises across the adapter boundary" do
      expect {
        expect(result.outcome).to eq(:retryable_failure)
        expect(result.error_code).to eq("smtp_transient")
      }.not_to raise_error
    end
  end
end
