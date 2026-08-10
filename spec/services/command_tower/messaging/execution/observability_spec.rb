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

  before do
    allow(CommandTower::Messaging::Contract::Observability::StructuredLogger).to receive(:info) do |payload|
      payloads << payload
    end
    allow(CommandTower::Messaging::Contract::Observability::StructuredLogger).to receive(:error) do |payload|
      payloads << payload
    end
  end

  let(:serialized) do
    lambda do |logged_payloads|
      logged_payloads.map { |payload| payload.to_json }.join("\n")
    end
  end

  context "when render and adapter succeed" do
    let(:previous_fake) { CommandTower.config.messaging.allow_fake_adapter }

    before do
      CommandTower.config.messaging.allow_fake_adapter = false
      CommandTower::Workflows::Messaging::Execution::DeliverWorkflow.call(channel_delivery_id: delivery.id)
    end

    after { CommandTower.config.messaging.allow_fake_adapter = previous_fake }

    let(:events) { payloads.map { |payload| payload[:event] || payload["event"] } }

    it "emits render and adapter success events with safe fields only" do
      expect(events).to include(
        "messaging.execution.readiness.revalidated",
        "messaging.execution.render.started",
        "messaging.execution.render.succeeded",
        "messaging.execution.adapter.started",
        "messaging.execution.adapter.accepted",
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
      payloads.find { |payload| (payload[:event] || payload["event"]) == "messaging.execution.render.failed" }
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
      payloads.find { |payload| (payload[:event] || payload["event"]) == "messaging.execution.adapter.terminal" }
    end

    it "emits adapter.terminal with safe error_code only" do
      expect(terminal_event).to be_present
      expect(terminal_event[:error_code] || terminal_event["error_code"]).to eq("smtp_rejected")
      expect(serialized.call(payloads)).not_to include(user.email)
    end
  end
end
