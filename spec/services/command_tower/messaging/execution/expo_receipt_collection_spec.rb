# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::ExpoReceiptCollection, :messaging_accept do
  let(:user) { create(:user) }
  let(:now) { Time.current }
  let(:build_delivery) do
    lambda do |status: "accepted_by_provider", attempt_count: 1|
      communication = create(
        :messaging_communication,
        user:,
        host_event_identity: "receipts-#{SecureRandom.hex(4)}",
        accept_request_fingerprint: "fp",
        status: "accepted",
        execution_handoff_status: "enqueued",
      )
      create(
        :messaging_channel_delivery,
        communication:,
        channel_key: "push",
        status:,
        execution_attempt_count: attempt_count,
      )
    end
  end
  let(:delivery) { build_delivery.call }
  let(:create_endpoint) do
    lambda do |address|
      view = CommandTower::Messaging::Endpoints.create(owner_user_id: user.id, channel_key: "push", address:)
      record = CommandTower::Messaging::Endpoint.find(view.id)
      record.update!(verification_state: "verified", verified_at: Time.current)
      record
    end
  end
  let!(:endpoint_a) { create_endpoint.call("ExponentPushToken[recpt0001]") }
  let!(:endpoint_b) { create_endpoint.call("ExponentPushToken[recpt0002]") }
  let!(:endpoint_c) { create_endpoint.call("ExponentPushToken[recpt0003]") }
  let(:pending_entry) do
    lambda do |endpoint, ticket_id|
      {
        "endpoint_id" => endpoint.id,
        "ticket_id" => ticket_id,
        "ticket_status" => "ok",
        "receipt_status" => "pending",
      }
    end
  end
  let(:record_attempt) do
    lambda do |entries, finished_ago: 2.minutes, target: delivery, status: "succeeded"|
      CommandTower::Messaging::DeliveryAttempt.create!(
        channel_delivery: target,
        status:,
        started_at: now - finished_ago - 5.seconds,
        finished_at: now - finished_ago,
        provider_message_id: "first-ticket",
        provider_metadata: { "expo" => { "endpoints" => entries } },
      )
    end
  end
  let(:entries_of) { ->(attempt) { attempt.reload.provider_metadata.dig("expo", "endpoints") } }

  let(:ok_receipt) { { status: "ok", message: nil, error: nil } }
  let(:gone_receipt) { { status: "error", message: "gone", error: "DeviceNotRegistered" } }
  let(:rate_receipt) { { status: "error", message: "slow", error: "MessageRateExceeded" } }
  let(:receipts) { {} }
  let(:receipt_response) { { ok: true, status_code: 200, receipts: } }
  let(:requested_ids) { [] }
  let(:http_client) { instance_double(CommandTower::Messaging::Execution::Adapters::Expo::HttpClient) }
  let(:adapter_name) { "http" }
  let(:expo_configured) { true }
  let(:configuration) do
    instance_double(
      CommandTower::Messaging::Execution::Adapters::Expo::Configuration,
      expo_configured?: expo_configured,
      adapter_name:,
    )
  end
  let(:collect) { described_class.call(configuration:, http_client:, now:) }
  let(:lifecycle_of) { ->(endpoint) { endpoint.reload.lifecycle_state } }

  let(:payloads) { [] }
  let(:subscriber) do
    bucket = payloads
    ActiveSupport::Notifications.subscribe(/\Acommand_tower\.messaging/) do |name, _s, _f, _id, payload|
      bucket << payload.to_h.merge(event: name)
    end
  end
  let(:receipt_events) do
    payloads.select { |payload| payload[:event] == "command_tower.messaging.execution.receipts.collected" }
  end

  before do
    subscriber
    allow(http_client).to receive(:get_receipts) do |ids|
      requested_ids << ids.dup
      receipt_response
    end
    allow(CommandTower::Messaging::Endpoints).to receive(:mark_invalid).and_call_original
  end

  after { unsubscribe_notifications(subscriber) }

  context "when pending receipts arrive" do
    let!(:attempt) do
      record_attempt.call(
        [
          pending_entry.call(endpoint_a, "t-a"),
          pending_entry.call(endpoint_b, "t-b"),
          pending_entry.call(endpoint_c, "t-c"),
        ],
      )
    end
    let(:receipts) { { "t-a" => ok_receipt, "t-b" => gone_receipt, "t-c" => rate_receipt } }
    let!(:counts) { collect }

    it "records each late outcome in the existing metadata" do
      expect(entries_of.call(attempt)).to eq(
        [
          { "endpoint_id" => endpoint_a.id, "ticket_id" => "t-a", "ticket_status" => "ok", "receipt_status" => "ok" },
          {
            "endpoint_id" => endpoint_b.id, "ticket_id" => "t-b", "ticket_status" => "ok",
            "receipt_status" => "error", "error_code" => "expo_device_invalid"
          },
          {
            "endpoint_id" => endpoint_c.id, "ticket_id" => "t-c", "ticket_status" => "ok",
            "receipt_status" => "error", "error_code" => "expo_rejected"
          },
        ],
      )
    end

    it "invalidates only the DeviceNotRegistered endpoint" do
      expect(lifecycle_of.call(endpoint_b)).to eq("invalid")
      expect(lifecycle_of.call(endpoint_a)).not_to eq("invalid")
      expect(lifecycle_of.call(endpoint_c)).not_to eq("invalid")
      expect(CommandTower::Messaging::Endpoints).to have_received(:mark_invalid).once
    end

    it "returns aggregate counts" do
      expect(counts).to include(
        attempt_count: 1, receipt_ok_count: 1, receipt_error_count: 2, invalidated_count: 1,
        receipt_unchecked_count: 0, poll_failure_count: 0, update_failure_count: 0
      )
    end

    it "requests every ticket in one call" do
      expect(requested_ids).to eq([%w[t-a t-b t-c]])
    end
  end

  context "when a receipt is still absent" do
    let!(:attempt) { record_attempt.call([pending_entry.call(endpoint_a, "t-a")]) }
    let!(:counts) { collect }

    it "leaves the entry pending and writes nothing" do
      expect(entries_of.call(attempt).first["receipt_status"]).to eq("pending")
      expect(counts.values.sum).to eq(0)
      expect(receipt_events).to be_empty
    end
  end

  context "with attempts around the receipt window" do
    let!(:inside) { record_attempt.call([pending_entry.call(endpoint_a, "t-in")], finished_ago: 14.minutes) }
    let!(:behind) { record_attempt.call([pending_entry.call(endpoint_b, "t-behind")], finished_ago: 20.minutes) }
    let!(:too_old) { record_attempt.call([pending_entry.call(endpoint_c, "t-old")], finished_ago: 40.minutes) }
    let!(:counts) { collect }

    it "polls only attempts inside the window and never marks them unchecked" do
      expect(requested_ids).to eq([%w[t-in]])
      expect(entries_of.call(inside).first["receipt_status"]).to eq("pending")
    end

    it "marks pending entries just behind the window unchecked without HTTP" do
      expect(entries_of.call(behind).first["receipt_status"]).to eq("unchecked")
      expect(counts[:receipt_unchecked_count]).to eq(1)
    end

    it "does not visit attempts older than the cleanup lookback" do
      expect(entries_of.call(too_old).first["receipt_status"]).to eq("pending")
    end
  end

  context "with entries that never qualify for polling" do
    let!(:attempt) do
      record_attempt.call(
        [
          {
            "endpoint_id" => endpoint_a.id, "ticket_status" => "error",
            "receipt_status" => "unchecked", "error_code" => "expo_rejected"
          },
          { "endpoint_id" => endpoint_b.id, "ticket_status" => "missing", "receipt_status" => "unchecked" },
          {
            "endpoint_id" => endpoint_c.id, "ticket_id" => "t-done",
            "ticket_status" => "ok", "receipt_status" => "ok"
          },
          {
            "endpoint_id" => endpoint_c.id, "ticket_id" => "t-gave-up",
            "ticket_status" => "ok", "receipt_status" => "unchecked"
          },
          { "endpoint_id" => endpoint_c.id, "ticket_status" => "ok", "receipt_status" => "pending" },
          { "endpoint_id" => endpoint_c.id, "error_code" => "recipient_missing" },
        ],
      )
    end
    let!(:before_entries) { attempt.provider_metadata.deep_dup }

    before { collect }

    it "does not request them and leaves them alone" do
      expect(http_client).not_to have_received(:get_receipts)
      expect(attempt.reload.provider_metadata).to eq(before_entries)
    end
  end

  context "when an accepted ticket is carried onto a later attempt" do
    let!(:original) do
      record_attempt.call(
        [pending_entry.call(endpoint_a, "t-a")],
        finished_ago: 5.minutes,
        status: "failed_retryable",
      )
    end
    let!(:carrying) do
      record_attempt.call(
        [
          {
            "endpoint_id" => endpoint_b.id, "ticket_status" => "missing",
            "receipt_status" => "unchecked", "error_code" => "expo_rejected"
          },
          { "endpoint_id" => endpoint_a.id, "ticket_id" => "t-a", "ticket_status" => "ok" },
        ],
        finished_ago: 2.minutes,
        status: "failed_terminal",
      )
    end
    let!(:carrying_before) { carrying.provider_metadata.deep_dup }
    let(:receipts) { { "t-a" => gone_receipt } }

    before { collect }

    it "polls the ticket once, from the attempt that recorded it" do
      expect(requested_ids).to eq([%w[t-a]])
      expect(entries_of.call(original).first)
        .to include("receipt_status" => "error", "error_code" => "expo_device_invalid")
    end

    it "leaves the carried copy untouched and invalidates once" do
      expect(carrying.reload.provider_metadata).to eq(carrying_before)
      expect(CommandTower::Messaging::Endpoints).to have_received(:mark_invalid).once
    end
  end

  context "when the receipt API fails" do
    let!(:inside) { record_attempt.call([pending_entry.call(endpoint_a, "t-a")]) }
    let!(:behind) { record_attempt.call([pending_entry.call(endpoint_b, "t-b")], finished_ago: 20.minutes) }

    [503, 429].each do |status_code|
      context "with a #{status_code} response" do
        let(:receipt_response) { { ok: false, status_code:, receipts: {} } }
        let!(:counts) { collect }

        it "keeps entries pending, invalidates nothing, and still cleans up" do
          expect(entries_of.call(inside).first["receipt_status"]).to eq("pending")
          expect(entries_of.call(behind).first["receipt_status"]).to eq("unchecked")
          expect(CommandTower::Messaging::Endpoints).not_to have_received(:mark_invalid)
          expect(counts).to include(poll_failure_count: 1, receipt_unchecked_count: 1)
        end

        it "logs one error-level aggregate event" do
          expect(receipt_events.size).to eq(1)
          expect(receipt_events.first).to include(poll_failure_count: 1)
        end
      end
    end

    context "when the request raises" do
      before { allow(http_client).to receive(:get_receipts).and_raise(Timeout::Error) }

      it "does not raise and keeps the entry pending" do
        expect { collect }.not_to raise_error
        expect(entries_of.call(inside).first["receipt_status"]).to eq("pending")
        expect(collect[:poll_failure_count]).to eq(1)
      end
    end
  end

  context "when invalidating an endpoint fails" do
    let!(:first_attempt) { record_attempt.call([pending_entry.call(endpoint_a, "t-a")], finished_ago: 6.minutes) }
    let!(:second_attempt) { record_attempt.call([pending_entry.call(endpoint_b, "t-b")], finished_ago: 3.minutes) }
    let(:receipts) { { "t-a" => gone_receipt, "t-b" => ok_receipt } }

    context "when the endpoint no longer exists" do
      before do
        allow(CommandTower::Messaging::Endpoints).to receive(:mark_invalid)
          .and_raise(CommandTower::Messaging::Endpoints::NotFoundError)
      end

      let!(:counts) { collect }

      it "still records the receipt error" do
        expect(entries_of.call(first_attempt).first)
          .to include("receipt_status" => "error", "error_code" => "expo_device_invalid")
        expect(counts).to include(receipt_error_count: 1, invalidated_count: 0, update_failure_count: 0)
      end
    end

    context "with an unexpected error" do
      before do
        allow(CommandTower::Messaging::Endpoints).to receive(:mark_invalid).and_raise(RuntimeError)
      end

      let!(:counts) { collect }

      it "rolls back only that attempt and keeps processing the next one" do
        expect(entries_of.call(first_attempt).first["receipt_status"]).to eq("pending")
        expect(entries_of.call(second_attempt).first["receipt_status"]).to eq("ok")
        expect(counts).to include(update_failure_count: 1, receipt_ok_count: 1, attempt_count: 1)
      end

      it "logs one error-level aggregate event" do
        expect(receipt_events.size).to eq(1)
        expect(receipt_events.first).to include(update_failure_count: 1)
      end
    end
  end

  context "when another sweep resolves an entry between the poll and the update" do
    let!(:attempt) { record_attempt.call([pending_entry.call(endpoint_a, "t-a")]) }
    let(:receipts) { { "t-a" => gone_receipt } }
    let(:resolved_metadata) do
      {
        "expo" => { "endpoints" => [
          {
            "endpoint_id" => endpoint_a.id, "ticket_id" => "t-a", "ticket_status" => "ok",
            "receipt_status" => "error", "error_code" => "expo_device_invalid"
          },
        ] },
      }
    end
    let(:attempt_id) { attempt.id }

    before do
      resolved = resolved_metadata
      id = attempt_id
      allow(http_client).to receive(:get_receipts) do |ids|
        requested_ids << ids.dup
        CommandTower::Messaging::DeliveryAttempt.find(id).update!(provider_metadata: resolved)
        receipt_response
      end
    end

    let!(:first_counts) { collect }

    it "does not overwrite the other sweep's result or invalidate again" do
      expect(attempt.reload.provider_metadata).to eq(resolved_metadata)
      expect(CommandTower::Messaging::Endpoints).not_to have_received(:mark_invalid)
      expect(first_counts).to include(attempt_count: 0, invalidated_count: 0)
    end

    it "makes no further HTTP call on a repeat run" do
      collect
      expect(requested_ids.size).to eq(1)
    end
  end

  context "when run twice after a resolved receipt" do
    let!(:attempt) { record_attempt.call([pending_entry.call(endpoint_a, "t-a")]) }
    let(:receipts) { { "t-a" => gone_receipt } }

    before do
      collect
      collect
    end

    it "polls and invalidates only once" do
      expect(requested_ids.size).to eq(1)
      expect(CommandTower::Messaging::Endpoints).to have_received(:mark_invalid).once
    end
  end

  context "with more candidates than one batch" do
    let(:finished_agos) { [9.minutes, 8.minutes, 8.minutes, 4.minutes, 3.minutes] }
    let!(:attempts) do
      finished_agos.each_with_index.map do |ago, index|
        record_attempt.call([pending_entry.call(endpoint_a, "t-#{index}")], finished_ago: ago)
      end
    end
    let(:receipts) { finished_agos.each_index.to_h { |index| ["t-#{index}", ok_receipt] } }

    before do
      stub_const("#{described_class}::BATCH_SIZE", 2)
      collect
    end

    it "reads several keyset batches and resolves every attempt once" do
      expect(requested_ids.size).to eq(3)
      expect(requested_ids.flatten).to match_array(%w[t-0 t-1 t-2 t-3 t-4])
      expect(attempts.map { |attempt| entries_of.call(attempt).first["receipt_status"] }).to all(eq("ok"))
    end
  end

  context "with more tickets than one request allows" do
    let!(:attempt) do
      record_attempt.call(
        [
          pending_entry.call(endpoint_a, "t-1"),
          pending_entry.call(endpoint_b, "t-2"),
          pending_entry.call(endpoint_c, "t-3"),
        ],
      )
    end
    let(:receipts) { { "t-1" => ok_receipt, "t-2" => ok_receipt, "t-3" => ok_receipt } }

    before do
      stub_const("#{described_class}::RECEIPT_ID_CHUNK_SIZE", 2)
      collect
    end

    it "sends the ids in chunks and de-duplicates them" do
      expect(requested_ids).to eq([%w[t-1 t-2], %w[t-3]])
    end
  end

  %w[fake log disabled].each do |name|
    context "with the #{name} adapter" do
      let(:adapter_name) { name }
      let(:expo_configured) { name != "disabled" }
      let!(:attempt) { record_attempt.call([pending_entry.call(endpoint_a, "t-a")], finished_ago: 20.minutes) }
      let!(:before_metadata) { attempt.provider_metadata.deep_dup }

      before { collect }

      it "does no HTTP and changes nothing" do
        expect(http_client).not_to have_received(:get_receipts)
        expect(attempt.reload.provider_metadata).to eq(before_metadata)
        expect(receipt_events).to be_empty
      end
    end
  end

  context "when deliveries are in any status" do
    let(:statuses) { %w[accepted_by_provider failed_retryable failed_terminal] }
    let(:deliveries) { statuses.map { |status| build_delivery.call(status:, attempt_count: 2) } }
    let!(:attempts) do
      deliveries.each_with_index.map do |target, index|
        record_attempt.call([pending_entry.call(endpoint_a, "t-#{index}")], target:)
      end
    end
    let(:receipts) { statuses.each_index.to_h { |index| ["t-#{index}", gone_receipt] } }

    before do
      clear_enqueued_jobs
      collect
    end

    it "never resends, never enqueues, and leaves statuses and counts alone" do
      expect(http_client).not_to have_received(:send_messages) if http_client.respond_to?(:send_messages)
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).not_to have_been_enqueued
      expect(deliveries.map { |target| target.reload.status }).to eq(statuses)
      expect(deliveries.map { |target| target.reload.execution_attempt_count }).to eq([2, 2, 2])
      expect(attempts.map { |attempt| attempt.reload.status }).to all(eq("succeeded"))
      expect(attempts.map { |attempt| attempt.reload.provider_message_id }).to all(eq("first-ticket"))
    end

    it "still records the late outcome on each attempt" do
      expect(attempts.map { |attempt| entries_of.call(attempt).first["receipt_status"] }).to all(eq("error"))
    end
  end

  context "when logging" do
    let!(:attempt) { record_attempt.call([pending_entry.call(endpoint_a, "t-secret-ticket")]) }
    let(:receipts) { { "t-secret-ticket" => gone_receipt } }
    let(:logged_dump) { payloads.map(&:inspect).join("\n") }
    let(:identifying_keys) do
      %i[channel_delivery_id communication_id delivery_attempt_id endpoint_id ticket_id provider_message_id]
    end

    before { collect }

    it "emits one aggregate event with counts only" do
      expect(receipt_events.size).to eq(1)
      expect(receipt_events.first.keys & identifying_keys).to be_empty
      expect(receipt_events.first.slice(*described_class::COUNT_KEYS)).to eq(
        attempt_count: 1, receipt_ok_count: 0, receipt_error_count: 1, receipt_unchecked_count: 0,
        invalidated_count: 1, poll_failure_count: 0, update_failure_count: 0
      )
    end

    it "never logs tokens, ticket ids, or endpoint ids" do
      expect(logged_dump).not_to include("ExponentPushToken")
      expect(logged_dump).not_to include("t-secret-ticket")
      expect(attempt.reload.provider_metadata.to_json).not_to include("ExponentPushToken")
    end
  end
end
