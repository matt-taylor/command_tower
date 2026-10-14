# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::Recovery, :messaging_accept do
  let(:user) { create(:user) }

  let(:build_delivery) do
    lambda do |status:, attempt_count: 1, claimed_at: nil, updated_at: 5.minutes.ago|
      communication = create(
        :messaging_communication,
        user:,
        host_event_identity: "rec-#{SecureRandom.hex(4)}",
        accept_request_fingerprint: "fp",
        status: "accepted",
        execution_handoff_status: "enqueued",
      )
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
      delivery = create(
        :messaging_channel_delivery,
        communication:,
        channel_key: "email",
        status:,
        execution_attempt_count: attempt_count,
        execution_claimed_at: claimed_at,
      )
      delivery.update_columns(updated_at:, execution_claimed_at: claimed_at)
      delivery
    end
  end

  context "with stranded queued work past the grace window" do
    let!(:delivery) { build_delivery.call(status: "queued", attempt_count: 0) }

    before { clear_enqueued_jobs }

    it "re-enqueues stranded queued work past the grace window" do
      described_class.call(grace_window: 1.minute)

      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob)
        .to have_been_enqueued.with(delivery.id)
    end
  end

  context "with failed_retryable under max attempts" do
    let!(:delivery) { build_delivery.call(status: "failed_retryable", attempt_count: 2) }

    before { clear_enqueued_jobs }

    it "resets failed_retryable to queued and re-enqueues when under max attempts" do
      described_class.call(grace_window: 1.minute)

      expect(delivery.reload.status).to eq("queued")
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob)
        .to have_been_enqueued.with(delivery.id)
    end
  end

  context "with failed_terminal delivery" do
    let!(:delivery) { build_delivery.call(status: "failed_terminal", attempt_count: 1) }

    before { clear_enqueued_jobs }

    it "does not redrive failed_terminal" do
      described_class.call(grace_window: 1.minute)

      expect(delivery.reload.status).to eq("failed_terminal")
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).not_to have_been_enqueued
    end
  end

  context "when max claim attempts are reached" do
    let!(:delivery) do
      build_delivery.call(
        status: "failed_retryable",
        attempt_count: CommandTower::Messaging::DeliveryRetryPolicy::MAX_ATTEMPTS,
      )
    end

    before { clear_enqueued_jobs }

    it "does not redrive when max claim attempts are reached" do
      described_class.call(grace_window: 1.minute)

      expect(delivery.reload.status).to eq("failed_retryable")
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).not_to have_been_enqueued
    end
  end

  context "when a mixed multi-device delivery reaches the attempt limit" do
    let!(:delivery) do
      build_delivery.call(
        status: "failed_retryable",
        attempt_count: CommandTower::Messaging::DeliveryRetryPolicy::MAX_ATTEMPTS,
      )
    end

    before do
      clear_enqueued_jobs
      CommandTower::Messaging::DeliveryAttempt.create!(
        channel_delivery: delivery,
        status: "failed_retryable",
        started_at: 1.minute.ago,
        provider_metadata: { "expo" => { "endpoints" => [
          { "endpoint_id" => 1, "ticket_id" => "t-1", "ticket_status" => "ok", "receipt_status" => "ok" },
          { "endpoint_id" => 2, "ticket_status" => "missing", "receipt_status" => "unchecked",
            "error_code" => "expo_transient" },
        ] } },
      )
    end

    it "does not redrive it and reports the retries as exhausted" do
      described_class.call(grace_window: 1.minute)

      expect(delivery.reload.status).to eq("failed_retryable")
      expect(CommandTower::Messaging::DeliveryRetryPolicy.retries_exhausted?(delivery)).to eq(true)
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).not_to have_been_enqueued
    end
  end

  context "with the receipt collection step" do
    let!(:delivery) { build_delivery.call(status: "failed_retryable", attempt_count: 2) }
    let(:call_order) { [] }

    before do
      clear_enqueued_jobs
      allow(CommandTower::Messaging::Execution::ExpoReceiptCollection).to receive(:call) do
        call_order << (delivery.reload.status == "queued" ? :after_redrive : :before_redrive)
        raise "receipt failure" if raise_in_collection

        {}
      end
    end

    context "when it succeeds" do
      let(:raise_in_collection) { false }

      it "runs after the redrive steps" do
        described_class.call(grace_window: 1.minute)

        expect(call_order).to eq([:after_redrive])
        expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).to have_been_enqueued.with(delivery.id)
      end
    end

    context "when it raises" do
      let(:raise_in_collection) { true }

      it "does not fail the sweep or undo the redrive" do
        expect { described_class.call(grace_window: 1.minute) }.not_to raise_error

        expect(delivery.reload.status).to eq("queued")
        expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).to have_been_enqueued.with(delivery.id)
      end
    end
  end

  context "with default grace and max attempts from DeliveryRetryPolicy" do
    let!(:delivery) do
      build_delivery.call(status: "failed_retryable", attempt_count: 1, updated_at: 5.minutes.ago)
    end

    before { clear_enqueued_jobs }

    it "defaults grace and max attempts from DeliveryRetryPolicy" do
      expect(CommandTower::Messaging::DeliveryRetryPolicy::GRACE_WINDOW).to eq(1.minute)
      expect(CommandTower::Messaging::DeliveryRetryPolicy::MAX_ATTEMPTS).to eq(5)

      described_class.call

      expect(delivery.reload.status).to eq("queued")
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob)
        .to have_been_enqueued.with(delivery.id)
    end
  end

  context "with stale executing work" do
    let!(:delivery) do
      build_delivery.call(
        status: "executing",
        attempt_count: 1,
        claimed_at: 5.minutes.ago,
      )
    end

    before { clear_enqueued_jobs }

    it "resets stale executing work to queued and re-enqueues" do
      described_class.call(grace_window: 1.minute)

      expect(delivery.reload.status).to eq("queued")
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob)
        .to have_been_enqueued.with(delivery.id)
    end
  end

  context "when running the full recovery path with fake adapter" do
    let(:previous_fake) { CommandTower.config.messaging.allow_fake_adapter }
    let!(:delivery) { build_delivery.call(status: "queued", attempt_count: 0) }
    let(:failure) do
      CommandTower::Messaging::Execution::Adapters::FakeAdapter.new(outcome: :retryable_failure)
    end
    let!(:communication_count) { CommandTower::Messaging::Communication.count }

    before do
      CommandTower.config.messaging.allow_fake_adapter = true

      CommandTower::Workflows::Messaging::Execution::DeliverWorkflow.call(
        channel_delivery_id: delivery.id,
        executor: failure,
      )
      delivery.update_columns(updated_at: 5.minutes.ago)
      clear_enqueued_jobs
    end

    after { CommandTower.config.messaging.allow_fake_adapter = previous_fake }

    it "runs the full recovery path with a new attempt under the same delivery" do
      expect(delivery.reload.status).to eq("failed_retryable")
      expect(delivery.delivery_attempts.count).to eq(1)

      described_class.call(grace_window: 1.minute)
      expect(delivery.reload.status).to eq("queued")

      perform_enqueued_jobs(only: CommandTower::Messaging::ChannelDeliveryExecutionJob)

      expect(delivery.reload.status).to eq("accepted_by_provider")
      expect(delivery.delivery_attempts.count).to eq(2)
      expect(CommandTower::Messaging::Communication.count).to eq(communication_count)
    end
  end
end
