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

  context "with push failed_retryable without not_submitted evidence" do
    let!(:delivery) do
      communication = create(
        :messaging_communication,
        user:,
        host_event_identity: "rec-push-#{SecureRandom.hex(4)}",
        accept_request_fingerprint: "fp",
        status: "accepted",
        execution_handoff_status: "enqueued",
      )
      create(
        :messaging_destination_plan,
        communication:,
        decision: {
          "selected_channels" => %w[push],
          "inbox_selected" => false,
          "mandatory" => false,
          "platform_enabled_channels" => %w[push],
          "excluded_destinations" => [],
        },
      )
      delivery = create(
        :messaging_channel_delivery,
        communication:,
        channel_key: "push",
        status: "failed_retryable",
        execution_attempt_count: 1,
      )
      delivery.update_columns(updated_at: 5.minutes.ago)
      CommandTower::Messaging::DeliveryAttempt.create!(
        channel_delivery: delivery,
        status: "failed_retryable",
        started_at: 2.minutes.ago,
        finished_at: 1.minute.ago,
        error_code: "internal_adapter_error",
      )
      delivery
    end

    before { clear_enqueued_jobs }

    it "terminalizes instead of redriving" do
      described_class.call(grace_window: 1.minute)

      expect(delivery.reload.status).to eq("failed_terminal")
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).not_to have_been_enqueued
    end
  end

  let(:build_push_delivery) do
    lambda do |status:, attempt_count: 1, updated_at: 5.minutes.ago|
      communication = create(
        :messaging_communication,
        user:,
        host_event_identity: "rec-push-#{SecureRandom.hex(4)}",
        accept_request_fingerprint: "fp",
        status: "accepted",
        execution_handoff_status: "enqueued",
      )
      create(
        :messaging_destination_plan,
        communication:,
        decision: {
          "selected_channels" => %w[push],
          "inbox_selected" => false,
          "mandatory" => false,
          "platform_enabled_channels" => %w[push],
          "excluded_destinations" => [],
        },
      )
      delivery = create(
        :messaging_channel_delivery,
        communication:,
        channel_key: "push",
        status:,
        execution_attempt_count: attempt_count,
      )
      delivery.update_columns(updated_at:)
      delivery
    end
  end

  context "with legacy push failed_retryable and a started attempt with null metadata" do
    let!(:delivery) { build_push_delivery.call(status: "failed_retryable", attempt_count: 1) }
    let!(:stuck_attempt) do
      CommandTower::Messaging::DeliveryAttempt.create!(
        channel_delivery: delivery,
        status: "started",
        started_at: 3.minutes.ago,
        finished_at: nil,
        provider_metadata: nil,
      )
    end

    before { clear_enqueued_jobs }

    it "terminalizes without enqueueing another execution" do
      described_class.call(grace_window: 1.minute)

      expect(delivery.reload.status).to eq("failed_terminal")
      expect(stuck_attempt.reload.status).to eq("failed_terminal")
      expect(stuck_attempt.error_code).to eq("submission_uncertain")
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).not_to have_been_enqueued
    end
  end

  context "with push queued past grace and an open started attempt" do
    let!(:delivery) { build_push_delivery.call(status: "queued", attempt_count: 1) }
    let!(:open_attempt) do
      CommandTower::Messaging::DeliveryAttempt.create!(
        channel_delivery: delivery,
        status: "started",
        started_at: 3.minutes.ago,
        finished_at: nil,
        provider_metadata: nil,
      )
    end

    before { clear_enqueued_jobs }

    it "terminalizes instead of redriving uncertain push work" do
      described_class.call(grace_window: 1.minute)

      expect(delivery.reload.status).to eq("failed_terminal")
      expect(open_attempt.reload.finished_at).to be_present
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).not_to have_been_enqueued
    end
  end

  context "when push retry budget is exhausted after two not_submitted attempts" do
    let!(:delivery) do
      build_push_delivery.call(
        status: "failed_retryable",
        attempt_count: CommandTower::Messaging::DeliveryRetryPolicy::PUSH_RETRY_LIMIT,
      )
    end

    before do
      clear_enqueued_jobs
      2.times do
        CommandTower::Messaging::DeliveryAttempt.create!(
          channel_delivery: delivery,
          status: "failed_retryable",
          started_at: 3.minutes.ago,
          finished_at: 2.minutes.ago,
          error_code: "expo_not_submitted",
          provider_metadata: { "submission" => "not_submitted" },
        )
      end
    end

    it "does not enqueue a third push execution" do
      described_class.call(grace_window: 1.minute)

      expect(delivery.reload.status).to eq("failed_terminal")
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).not_to have_been_enqueued
    end
  end

  context "with push accepted_by_provider and persisted ok ticket metadata" do
    let!(:delivery) do
      build_push_delivery.call(status: "accepted_by_provider", attempt_count: 1)
    end

    before do
      clear_enqueued_jobs
      CommandTower::Messaging::DeliveryAttempt.create!(
        channel_delivery: delivery,
        status: "succeeded",
        started_at: 2.minutes.ago,
        finished_at: 1.minute.ago,
        provider_metadata: {
          "expo" => {
            "endpoints" => [
              { "endpoint_id" => 1, "ticket_id" => "t-ok", "ticket_status" => "ok", "receipt_status" => "ok" },
            ],
          },
        },
      )
      delivery.update_columns(updated_at: 5.minutes.ago)
    end

    it "never re-enters recovery redrive" do
      described_class.call(grace_window: 1.minute)

      expect(delivery.reload.status).to eq("accepted_by_provider")
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).not_to have_been_enqueued
    end
  end

  context "with push confirmed not_submitted evidence" do
    let(:previous_fake) { CommandTower.config.messaging.allow_fake_adapter }
    let(:previous_expo_adapter) { CommandTower.config.messaging.expo.adapter }
    let(:previous_home) { CommandTower.config.messaging.expo.home_deep_link }
    let!(:delivery) do
      communication = create(
        :messaging_communication,
        user:,
        host_event_identity: "rec-push-ns-#{SecureRandom.hex(4)}",
        accept_request_fingerprint: "fp",
        status: "accepted",
        execution_handoff_status: "enqueued",
      )
      create(
        :messaging_destination_plan,
        communication:,
        decision: {
          "selected_channels" => %w[push],
          "inbox_selected" => false,
          "mandatory" => false,
          "platform_enabled_channels" => %w[push],
          "excluded_destinations" => [],
        },
      )
      delivery = create(
        :messaging_channel_delivery,
        communication:,
        channel_key: "push",
        status: "failed_retryable",
        execution_attempt_count: 1,
      )
      delivery.update_columns(updated_at: 5.minutes.ago)
      CommandTower::Messaging::DeliveryAttempt.create!(
        channel_delivery: delivery,
        status: "failed_retryable",
        started_at: 2.minutes.ago,
        finished_at: 1.minute.ago,
        error_code: "expo_not_submitted",
        provider_metadata: { "submission" => "not_submitted" },
      )
      delivery
    end

    before do
      view = CommandTower::Messaging::Endpoints.create(
        owner_user_id: user.id,
        channel_key: "push",
        address: "ExponentPushToken[recovery-ns]",
      )
      record = CommandTower::Messaging::Endpoint.find(view.id)
      record.update!(verification_state: "verified", verified_at: Time.current)

      CommandTower.config.messaging.allow_fake_adapter = true
      CommandTower.config.messaging.expo.adapter = "fake"
      CommandTower.config.messaging.expo.home_deep_link = "pickem://home"
      clear_enqueued_jobs
    end

    after do
      CommandTower.config.messaging.allow_fake_adapter = previous_fake
      CommandTower.config.messaging.expo.adapter = previous_expo_adapter
      CommandTower.config.messaging.expo.home_deep_link = previous_home
    end

    it "requeues and the permitted retry executes through queued and claim" do
      described_class.call(grace_window: 1.minute)

      expect(delivery.reload.status).to eq("queued")
      expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).to have_been_enqueued.with(delivery.id)

      perform_enqueued_jobs(only: CommandTower::Messaging::ChannelDeliveryExecutionJob)

      last_attempt = delivery.delivery_attempts.order(:id).last
      expect([last_attempt.status, last_attempt.error_code, delivery.reload.status])
        .to eq(["succeeded", nil, "accepted_by_provider"])
      expect(delivery.execution_attempt_count).to eq(2)
      expect(delivery.delivery_attempts.count).to eq(2)
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
