# frozen_string_literal: true

RSpec.describe "Messaging execution observability", :messaging_accept do
  let(:user) { create(:user, email: "recipient@example.com") }
  let(:communication) do
    create(
      :messaging_communication,
      user:,
      title: "Secret Title Payload",
      body: "Secret body with PII details",
      metadata: { "deep_link" => "https://example.com/secret-path" },
      host_event_identity: "obs-#{SecureRandom.hex(4)}",
      accept_request_fingerprint: "fp",
      status: "accepted",
      execution_handoff_status: "enqueued",
    )
  end
  let!(:destination_plan) do
    create(
      :messaging_destination_plan,
      communication:,
      decision: {
        "selected_channels" => %w[email],
        "inbox_selected" => false,
        "mandatory" => false,
        "platform_enabled_channels" => %w[email],
        "excluded_destinations" => [],
      },
    )
  end
  let(:delivery) do
    create(
      :messaging_channel_delivery,
      communication:,
      channel_key: "email",
      status: "queued",
      execution_attempt_count: 0,
    )
  end

  let(:payloads) { [] }
  let(:subscriber) do
    bucket = payloads
    ActiveSupport::Notifications.subscribe(/\Acommand_tower\.messaging/) do |name, _s, _f, _id, payload|
      bucket << payload.to_h.merge(event: name)
    end
  end

  before { subscriber }

  after { unsubscribe_notifications(subscriber) }

  let(:serialized) do
    lambda do |logged_payloads|
      logged_payloads.map(&:inspect).join("\n")
    end
  end

  context "when render and adapter succeed" do
    around do |example|
      previous_fake = CommandTower.config.messaging.allow_fake_adapter
      CommandTower.config.messaging.allow_fake_adapter = false
      example.run
    ensure
      CommandTower.config.messaging.allow_fake_adapter = previous_fake
    end

    before do
      CommandTower::Workflows::Messaging::Execution::DeliverWorkflow.call(channel_delivery_id: delivery.id)
    end

    let(:events) { payloads.map { |payload| payload[:event] || payload["event"] } }

    it "emits render and adapter success events with safe fields only" do
      expect(events).to include(
        "command_tower.messaging.execution.readiness.revalidated",
        "command_tower.messaging.execution.render.started",
        "command_tower.messaging.execution.render.succeeded",
        "command_tower.messaging.execution.adapter.started",
        "command_tower.messaging.execution.adapter.accepted",
      )

      dump = serialized.call(payloads)
      expect(dump).not_to include(user.email)
      expect(dump).not_to include("Secret Title Payload")
      expect(dump).not_to include("Secret body with PII details")
      expect(dump).not_to include("https://example.com/secret-path")
      expect(dump).not_to include("GMAIL_PASSWORD")
      expect(payloads).to all(satisfy { |payload| payload.keys.map(&:to_s).none? { |k| %w[title body email password text html metadata].include?(k) } })
    end
  end

  context "when rendering raises" do
    before do
      allow(CommandTower::Messaging::Rendering::ChannelRenderer).to receive(:render).and_raise(
        CommandTower::Messaging::Rendering::RenderError.new(
          code: "render_failed",
          error_class: "Errno::ENOENT",
        ),
      )

      CommandTower::Workflows::Messaging::Execution::DeliverWorkflow.call(
        channel_delivery_id: delivery.id,
        executor: CommandTower::Messaging::Execution::Adapters::FakeAdapter.new,
      )
    end

    let(:failed_event) do
      payloads.find { |payload| (payload[:event] || payload["event"]) == "command_tower.messaging.execution.render.failed" }
    end

    it "emits render.failed with safe classification and no raw exception message" do
      expect(failed_event).to be_present
      expect(failed_event[:error_code] || failed_event["error_code"]).to eq("render_failed")
      expect(failed_event[:error_class] || failed_event["error_class"]).to eq("Errno::ENOENT")

      dump = serialized.call(payloads)
      expect(dump).not_to include(user.email)
      expect(dump).not_to include("Secret Title Payload")
      expect(dump).not_to include("No such file")
    end
  end

  context "when the adapter result carries per-device provider_metadata" do
    let(:accepted_event_name) { "command_tower.messaging.execution.adapter.accepted" }
    let(:count_keys) { %i[endpoint_count ticket_ok_count ticket_error_count receipt_pending_count] }
    let(:provider_metadata) do
      {
        "expo" => {
          "endpoints" => [
            { "endpoint_id" => 11, "ticket_id" => "t-1", "ticket_status" => "ok", "receipt_status" => "pending" },
            {
              "endpoint_id" => 12, "ticket_id" => "ticket-second-9f3a",
              "ticket_status" => "ok", "receipt_status" => "ok"
            },
            {
              "endpoint_id" => 13, "ticket_status" => "error",
              "receipt_status" => "unchecked", "error_code" => "expo_rejected"
            },
            { "endpoint_id" => 14, "ticket_status" => "missing", "receipt_status" => "unchecked" },
            { "endpoint_id" => 15, "error_code" => "recipient_missing" },
          ],
        },
      }
    end
    let(:adapter) do
      instance_double(
        CommandTower::Messaging::Execution::Adapters::FakeAdapter,
        call: CommandTower::Messaging::Execution::AdapterResult.build(
          outcome: :success,
          normalized_provider_status: "accepted",
          provider_message_id: "t-1",
          provider_metadata:,
        ),
      )
    end
    let(:accepted_event) do
      payloads.find { |payload| (payload[:event] || payload["event"]) == accepted_event_name }
    end
    let(:dump) { serialized.call(payloads) }

    before do
      CommandTower::Workflows::Messaging::Execution::DeliverWorkflow.call(
        channel_delivery_id: delivery.id,
        executor: adapter,
      )
    end

    it "adds counts to adapter.accepted and nothing identifying" do
      expect(accepted_event.slice(*count_keys)).to eq(
        endpoint_count: 5,
        ticket_ok_count: 2,
        ticket_error_count: 2,
        receipt_pending_count: 1,
      )
      expect(dump).not_to include("ExponentPushToken")
      expect(dump).not_to include("ticket-second-9f3a")
      expect(dump).not_to include("Secret Title Payload")
    end
  end

  context "when the adapter result has no provider_metadata" do
    let(:accepted_event_name) { "command_tower.messaging.execution.adapter.accepted" }
    let(:count_keys) { %i[endpoint_count ticket_ok_count ticket_error_count receipt_pending_count] }
    let(:adapter) { CommandTower::Messaging::Execution::Adapters::FakeAdapter.new(outcome: :success) }
    let(:accepted_event) do
      payloads.find { |payload| (payload[:event] || payload["event"]) == accepted_event_name }
    end

    before do
      CommandTower::Workflows::Messaging::Execution::DeliverWorkflow.call(
        channel_delivery_id: delivery.id,
        executor: adapter,
      )
    end

    it "adds no count fields" do
      expect(accepted_event.keys).not_to include(*count_keys)
    end
  end

  context "when adapter returns terminal failure" do
    let(:adapter) do
      CommandTower::Messaging::Execution::Adapters::FakeAdapter.new(
        outcome: :terminal_failure,
        error_code: "smtp_rejected",
      )
    end

    before do
      CommandTower::Workflows::Messaging::Execution::DeliverWorkflow.call(
        channel_delivery_id: delivery.id,
        executor: adapter,
      )
    end

    let(:terminal_event) do
      payloads.find { |payload| (payload[:event] || payload["event"]) == "command_tower.messaging.execution.adapter.terminal" }
    end

    it "emits adapter.terminal with safe error_code only" do
      expect(terminal_event).to be_present
      expect(terminal_event[:error_code] || terminal_event["error_code"]).to eq("smtp_rejected")
      expect(serialized.call(payloads)).not_to include(user.email)
    end
  end

  context "when the receipt sweep reports counts" do
    let(:event_name) { "command_tower.messaging.execution.receipts.collected" }
    let(:counts) do
      {
        attempt_count: 2, receipt_ok_count: 1, receipt_error_count: 1, receipt_unchecked_count: 0,
        invalidated_count: 1, poll_failure_count: 0, update_failure_count: 0
      }
    end
    let(:events) { payloads.select { |payload| payload[:event] == event_name } }
    let(:identifying_keys) { %i[channel_delivery_id communication_id delivery_attempt_id endpoint_id ticket_id] }

    context "with activity and no failures" do
      before { CommandTower::Messaging::Execution::OperationLogger.receipts_collected(counts) }

      it "emits one info event with counts only" do
        expect(events.size).to eq(1)
        expect(events.first.slice(*counts.keys)).to eq(counts)
        expect(events.first[:log_level].to_s).to eq("info")
        expect(events.first.keys & identifying_keys).to be_empty
      end
    end

    context "with a failure count" do
      let(:failing_counts) { counts.merge(update_failure_count: 1) }

      before { CommandTower::Messaging::Execution::OperationLogger.receipts_collected(failing_counts) }

      it "emits at error level" do
        expect(events.first[:log_level].to_s).to eq("error")
      end
    end

    context "with every count zero" do
      before { CommandTower::Messaging::Execution::OperationLogger.receipts_collected(counts.transform_values { 0 }) }

      it "emits nothing" do
        expect(events).to be_empty
      end
    end
  end
end
