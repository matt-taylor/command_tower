# frozen_string_literal: true

RSpec.describe "Messaging execution scheduling", :messaging_accept do
  self.use_transactional_tests = false

  let(:user) { create(:user) }
  let(:notification_type_key) { "booking.success" }
  let(:platform_enabled_channels) { %w[email] }

  around do |example|
    DatabaseCleaner.clean_with(:truncation)
    previous = CommandTower.config.messaging.allow_fake_adapter
    CommandTower.config.messaging.allow_fake_adapter = true
    example.run
  ensure
    CommandTower.config.messaging.allow_fake_adapter = previous
    DatabaseCleaner.clean_with(:truncation)
  end

  before do
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: notification_type_key,
        allowed_channels: %w[email],
        default_channels: %w[email],
        inbox_available: true,
        user_configurable: true,
        mandatory: false,
        default_preference_state: {
          "channels" => { "email" => true },
          "inbox" => true,
        },
      ),
    )
  end

  let(:accept) do
    lambda do |**overrides|
      CommandTower::Messaging.accept(
        **default_accept_attrs(user:, notification_type_key:, platform_enabled_channels:, **overrides),
      )
    end
  end

  context "when handoff queues deliveries" do
    let(:host_event_identity) { "exec-sched-#{SecureRandom.hex(4)}" }
    let!(:accept_result) { accept.call(host_event_identity:) }

    it "enqueues HandoffJob after accept" do
      expect(CommandTower::Messaging::HandoffJob).to have_been_enqueued
    end

    context "after handoff job runs" do
      before { perform_enqueued_jobs(only: CommandTower::Messaging::HandoffJob) }

      let(:delivery_ids) do
        CommandTower::Messaging::ChannelDelivery
          .where(communication_id: accept_result.communication_id)
          .pluck(:id)
      end

      it "schedules ChannelDeliveryExecutionJob for each delivery" do
        expect(delivery_ids).not_to be_empty
        delivery_ids.each do |id|
          expect(CommandTower::Messaging::ChannelDeliveryExecutionJob).to have_been_enqueued.with(id)
        end
        expect(
          CommandTower::Messaging::ChannelDelivery.where(id: delivery_ids).pluck(:status).uniq,
        ).to eq(["queued"])
      end
    end
  end

  context "after handoff completes" do
    let(:host_event_identity) { "e2e-#{SecureRandom.hex(4)}" }
    let!(:accept_result) { accept.call(host_event_identity:) }

    before { perform_enqueued_jobs(only: CommandTower::Messaging::HandoffJob) }

    let(:delivery_statuses) do
      CommandTower::Messaging::ChannelDelivery.where(communication_id: accept_result.communication_id).pluck(:status)
    end

    it "leaves deliveries queued with no attempts yet" do
      expect(delivery_statuses).to eq(["queued"])
      expect(CommandTower::Messaging::DeliveryAttempt.count).to eq(0)
    end
  end

  context "after execution completes" do
    let(:host_event_identity) { "e2e-#{SecureRandom.hex(4)}" }
    let!(:accept_result) { accept.call(host_event_identity:) }

    before do
      perform_enqueued_jobs(only: CommandTower::Messaging::HandoffJob)
      perform_enqueued_jobs(only: CommandTower::Messaging::ChannelDeliveryExecutionJob)
    end

    let(:deliveries) do
      CommandTower::Messaging::ChannelDelivery.where(communication_id: accept_result.communication_id)
    end

    it "runs Accept → Handoff → queued → accepted_by_provider with an attempt" do
      expect(deliveries.pluck(:status)).to eq(["accepted_by_provider"])
      expect(CommandTower::Messaging::DeliveryAttempt.count).to eq(1)
      expect(deliveries.pluck(:status)).not_to include("delivered", "sent", "executed")
    end
  end

  context "when the execution enqueue fails" do
    let(:execution_enqueue_gate) { { should_fail: true } }
    let(:host_event_identity) { "exec-enq-fail-#{SecureRandom.hex(4)}" }
    let!(:accept_result) { accept.call(host_event_identity:) }

    before do
      allow(CommandTower::Messaging::ChannelDeliveryExecutionJob)
        .to receive(:perform_later).and_wrap_original do |original, *args, **kwargs|
          if execution_enqueue_gate[:should_fail]
            raise RuntimeError, "enqueue failed"
          else
            original.call(*args, **kwargs)
          end
        end
    end

    before { perform_enqueued_jobs(only: CommandTower::Messaging::HandoffJob) }

    let(:delivery) do
      CommandTower::Messaging::ChannelDelivery.find_by!(communication_id: accept_result.communication_id)
    end

    it "leaves queued when execution enqueue fails" do
      expect(delivery.status).to eq("queued")
      expect(CommandTower::Messaging::DeliveryAttempt.count).to eq(0)
    end

    context "after recovery restores execution" do
      before do
        execution_enqueue_gate[:should_fail] = false
        delivery.update_columns(updated_at: 5.minutes.ago)
        clear_enqueued_jobs
        CommandTower::Messaging::Execution::Recovery.call(grace_window: 1.minute)
        perform_enqueued_jobs(only: CommandTower::Messaging::ChannelDeliveryExecutionJob)
      end

      it "accepts by provider with an attempt" do
        expect(delivery.reload.status).to eq("accepted_by_provider")
        expect(delivery.delivery_attempts.count).to eq(1)
      end
    end
  end
end
