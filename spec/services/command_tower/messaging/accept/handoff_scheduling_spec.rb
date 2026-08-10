# frozen_string_literal: true

RSpec.describe "Messaging Accept handoff scheduling", :messaging_accept do
  self.use_transactional_tests = false

  let(:user) { create(:user) }
  let(:notification_type_key) { "booking.success" }
  let(:platform_enabled_channels) { %w[email sms] }

  around do |example|
    DatabaseCleaner.clean_with(:truncation)
    example.run
    DatabaseCleaner.clean_with(:truncation)
  end

  before do
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: notification_type_key,
        allowed_channels: %w[email sms],
        default_channels: %w[email],
        inbox_available: true,
        user_configurable: true,
        mandatory: false,
        default_preference_state: {
          "channels" => { "email" => true, "sms" => true },
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

  it "does not enqueue HandoffJob before the Accept transaction commits" do
    clear_enqueued_jobs

    ActiveRecord::Base.transaction do
      accept.call(host_event_identity: "pre-commit-#{SecureRandom.hex(4)}")
      expect(enqueued_jobs).to be_empty
      raise ActiveRecord::Rollback
    end

    expect(enqueued_jobs).to be_empty
    expect(CommandTower::Messaging::Communication.count).to eq(0)
  end

  context "after Accept commits" do
    let(:host_event_identity) { "after-commit-#{SecureRandom.hex(4)}" }
    let(:result) { accept.call(host_event_identity:) }

    before do
      clear_enqueued_jobs
      result
    end

    it "enqueues HandoffJob after Accept commits" do
      expect(CommandTower::Messaging::HandoffJob).to have_been_enqueued.with(result.communication_id)
    end
  end

  context "when a Communication is created outside Accept" do
    before do
      clear_enqueued_jobs

      CommandTower::Messaging::Communication.create!(
        user_id: user.id,
        notification_type_key: "booking.success",
        host_event_identity: "outside-#{SecureRandom.hex(4)}",
        accept_request_fingerprint: "fp",
        status: "accepted",
        execution_handoff_status: "pending",
        title: "t",
        body: "b",
      )
    end

    it "does not auto-enqueue when a Communication is created outside Accept" do
      expect(CommandTower::Messaging::HandoffJob).not_to have_been_enqueued
    end
  end

  context "on idempotent replay when handoff is already terminal" do
    let(:identity) { "replay-#{SecureRandom.hex(4)}" }
    let(:first) { accept.call(host_event_identity: identity) }

    before do
      first
      perform_enqueued_jobs(only: CommandTower::Messaging::HandoffJob)
      expect(
        CommandTower::Messaging::Communication.find(first.communication_id).execution_handoff_status,
      ).to eq("enqueued")

      clear_enqueued_jobs
    end

    subject(:second) { accept.call(host_event_identity: identity) }

    it "does not enqueue again on idempotent replay when handoff is already terminal" do
      expect(second.idempotent_replay).to be(true)
      expect(CommandTower::Messaging::HandoffJob).not_to have_been_enqueued
    end
  end

  context "when the initial handoff enqueue fails" do
    let(:handoff_enqueue_gate) { { should_fail: true } }
    let(:identity) { "enqueue-fail-#{SecureRandom.hex(4)}" }
    let(:result) { accept.call(host_event_identity: identity) }
    let(:communication) { CommandTower::Messaging::Communication.find(result.communication_id) }

    before do
      allow(CommandTower::Messaging::HandoffJob).to receive(:perform_later).and_wrap_original do |original, *args, **kwargs|
        if handoff_enqueue_gate[:should_fail]
          raise RuntimeError, "enqueue failed"
        else
          original.call(*args, **kwargs)
        end
      end

      result
    end

    it "leaves pending when enqueue fails" do
      expect(communication.execution_handoff_status).to eq("pending")
      expect(communication.channel_deliveries.pluck(:status).uniq).to eq(["planned"])
    end

    context "after recovery restores eligibility" do
      before do
        handoff_enqueue_gate[:should_fail] = false
        communication.update_columns(updated_at: 5.minutes.ago)
        clear_enqueued_jobs

        CommandTower::Messaging::Handoff::Recovery.call(grace_window: 1.minute)
        perform_enqueued_jobs(only: CommandTower::Messaging::HandoffJob)
      end

      it "restores enqueued handoff and queued deliveries" do
        communication.reload
        expect(communication.execution_handoff_status).to eq("enqueued")
        expect(communication.channel_deliveries.pluck(:status).uniq).to eq(["queued"])
      end
    end
  end
end
