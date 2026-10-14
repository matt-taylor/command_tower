# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::Adapters::Expo::EndpointTicketHistory, :messaging_accept do
  let(:user) { create(:user) }
  let(:communication) do
    create(
      :messaging_communication,
      user:,
      host_event_identity: "ticket-history-#{SecureRandom.hex(4)}",
      accept_request_fingerprint: "fp",
      status: "accepted",
      execution_handoff_status: "enqueued",
    )
  end
  let(:delivery) { create(:messaging_channel_delivery, communication:, channel_key: "push", status: "queued") }
  let(:record_attempt) do
    lambda do |metadata:, target: delivery, started_at: Time.current|
      CommandTower::Messaging::DeliveryAttempt.create!(
        channel_delivery: target,
        status: "failed_retryable",
        started_at:,
        provider_metadata: metadata,
      )
    end
  end
  let(:excluded_id) { nil }

  subject(:history) { described_class.call(channel_delivery_id: delivery.id, excluding_attempt_id: excluded_id) }

  context "with no earlier attempts" do
    it "is empty" do
      expect(history.accepted_ticket_ids).to eq({})
      expect(history.terminal_error_codes).to eq({})
      expect(history.settled_endpoint_ids).to eq([])
      expect(history.accepted?).to eq(false)
    end
  end

  context "with accepted tickets recorded on different earlier attempts" do
    before do
      record_attempt.call(
        started_at: 3.minutes.ago,
        metadata: { "expo" => { "endpoints" => [
          { "endpoint_id" => 1, "ticket_id" => "t-a", "ticket_status" => "ok", "receipt_status" => "pending" },
          { "endpoint_id" => 2, "ticket_status" => "missing", "receipt_status" => "unchecked" },
        ] } },
      )
      record_attempt.call(
        started_at: 2.minutes.ago,
        metadata: { "expo" => { "endpoints" => [
          { "endpoint_id" => 2, "ticket_id" => "t-b", "ticket_status" => "ok", "receipt_status" => "ok" },
        ] } },
      )
    end

    it "unions the accepted tickets across attempts in recorded order" do
      expect(history.accepted_ticket_ids).to eq(1 => "t-a", 2 => "t-b")
      expect(history.first_accepted_ticket_id).to eq("t-a")
      expect(history.terminal_error_codes).to eq({})
    end
  end

  context "with terminal ticket errors recorded" do
    before do
      record_attempt.call(
        metadata: { "expo" => { "endpoints" => [
          { "endpoint_id" => 5, "ticket_status" => "error", "receipt_status" => "unchecked",
            "error_code" => "expo_rejected" },
          { "endpoint_id" => 6, "ticket_status" => "error", "receipt_status" => "unchecked",
            "error_code" => "expo_device_invalid" },
        ] } },
      )
    end

    it "reports each endpoint with its error code and counts them as settled" do
      expect(history.terminal_error_codes).to eq(5 => "expo_rejected", 6 => "expo_device_invalid")
      expect(history.first_terminal_error_code).to eq("expo_rejected")
      expect(history.settled_endpoint_ids).to contain_exactly(5, 6)
      expect(history.accepted?).to eq(false)
    end
  end

  context "when an accepted ticket has a failed receipt" do
    before do
      record_attempt.call(
        metadata: { "expo" => { "endpoints" => [
          { "endpoint_id" => 12, "ticket_id" => "t-12", "ticket_status" => "ok", "receipt_status" => "error",
            "error_code" => "expo_device_invalid" },
        ] } },
      )
    end

    it "treats the device as a terminal failure, not an accepted delivery" do
      expect(history.accepted?).to eq(false)
      expect(history.terminal_error_codes).to eq(12 => "expo_device_invalid")
    end
  end

  context "when an endpoint is recorded as accepted and as an error" do
    before do
      record_attempt.call(
        started_at: 2.minutes.ago,
        metadata: { "expo" => { "endpoints" => [
          { "endpoint_id" => 7, "ticket_status" => "error", "error_code" => "expo_rejected" },
        ] } },
      )
      record_attempt.call(
        started_at: 1.minute.ago,
        metadata: { "expo" => { "endpoints" => [
          { "endpoint_id" => 7, "ticket_id" => "t-7", "ticket_status" => "ok" },
        ] } },
      )
    end

    it "treats the endpoint as accepted only" do
      expect(history.accepted_ticket_ids).to eq(7 => "t-7")
      expect(history.terminal_error_codes).to eq({})
    end
  end

  context "with entries that settle nothing" do
    before do
      record_attempt.call(metadata: nil)
      record_attempt.call(
        metadata: { "expo" => { "endpoints" => [
          { "endpoint_id" => 8, "ticket_status" => "missing", "receipt_status" => "unchecked",
            "error_code" => "expo_transient" },
          { "endpoint_id" => 9, "error_code" => "recipient_missing" },
        ] } },
      )
    end

    it "ignores null metadata, missing tickets, and never-submitted endpoints" do
      expect(history.settled_endpoint_ids).to eq([])
    end
  end

  context "with the current attempt excluded" do
    let!(:current) do
      record_attempt.call(
        metadata: { "expo" => { "endpoints" => [
          { "endpoint_id" => 10, "ticket_id" => "t-now", "ticket_status" => "ok" },
        ] } },
      )
    end
    let(:excluded_id) { current.id }

    it "does not read the excluded attempt" do
      expect(history.settled_endpoint_ids).to eq([])
    end
  end

  context "with an attempt that belongs to another delivery" do
    let(:other_delivery) do
      other_communication = create(
        :messaging_communication,
        user:,
        host_event_identity: "ticket-history-other-#{SecureRandom.hex(4)}",
        accept_request_fingerprint: "fp2",
        status: "accepted",
        execution_handoff_status: "enqueued",
      )
      create(:messaging_channel_delivery, communication: other_communication, channel_key: "push", status: "queued")
    end

    before do
      record_attempt.call(
        target: other_delivery,
        metadata: { "expo" => { "endpoints" => [
          { "endpoint_id" => 11, "ticket_id" => "t-other", "ticket_status" => "ok" },
        ] } },
      )
    end

    it "ignores it" do
      expect(history.settled_endpoint_ids).to eq([])
    end
  end
end
