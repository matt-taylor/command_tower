# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::AttemptLedger, :messaging_accept do
  let(:user) { create(:user) }
  let(:communication) do
    create(
      :messaging_communication,
      user:,
      host_event_identity: "attempt-ledger-#{SecureRandom.hex(4)}",
      accept_request_fingerprint: "fp",
      status: "accepted",
      execution_handoff_status: "enqueued",
    )
  end
  let(:delivery) do
    create(:messaging_channel_delivery, communication:, channel_key: "push", status: "executing")
  end
  let(:attempt) { described_class.start(delivery:) }
  let(:provider_metadata) do
    { "expo" => { "endpoints" => [{ "endpoint_id" => 7, "ticket_id" => "t-1", "ticket_status" => "ok" }] } }
  end

  context "when finalizing a successful adapter result" do
    subject(:finalize) do
      described_class.finalize_from_adapter(
        delivery:,
        attempt:,
        result: CommandTower::Messaging::Execution::AdapterResult.build(
          outcome: :success,
          normalized_provider_status: "accepted",
          provider_message_id: "t-1",
          provider_metadata:,
        ),
      )
    end

    it "persists provider_metadata on the attempt" do
      finalize
      expect(attempt.reload.provider_metadata).to eq(provider_metadata)
    end
  end

  context "when finalizing a retryable adapter result" do
    subject(:finalize) do
      described_class.finalize_from_adapter(
        delivery:,
        attempt:,
        result: CommandTower::Messaging::Execution::AdapterResult.build(
          outcome: :retryable_failure,
          error_code: "expo_transient",
          provider_metadata:,
        ),
      )
    end

    it "persists provider_metadata on the attempt" do
      finalize
      expect(attempt.reload.provider_metadata).to eq(provider_metadata)
    end
  end

  context "when finalizing a terminal adapter result" do
    subject(:finalize) do
      described_class.finalize_from_adapter(
        delivery:,
        attempt:,
        result: CommandTower::Messaging::Execution::AdapterResult.build(
          outcome: :terminal_failure,
          error_code: "expo_device_invalid",
          provider_metadata:,
        ),
      )
    end

    it "persists provider_metadata on the attempt" do
      finalize
      expect(attempt.reload.provider_metadata).to eq(provider_metadata)
    end
  end

  context "when the adapter result has no provider_metadata" do
    subject(:finalize) do
      described_class.finalize_from_adapter(
        delivery:,
        attempt:,
        result: CommandTower::Messaging::Execution::AdapterResult.build(outcome: :success),
      )
    end

    it "leaves provider_metadata null" do
      finalize
      expect(attempt.reload.provider_metadata).to be_nil
    end
  end

  context "when finalizing an unexpected error" do
    subject(:finalize) { described_class.finalize_unexpected(delivery:, attempt:, error_class: "RuntimeError") }

    it "leaves provider_metadata null" do
      finalize
      expect(attempt.reload.provider_metadata).to be_nil
    end
  end
end
