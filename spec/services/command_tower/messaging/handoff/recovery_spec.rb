# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Handoff::Recovery, :messaging_accept do
  let(:user) { create(:user) }
  let(:notification_type_key) { "booking.success" }

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
        **default_accept_attrs(
          user:,
          notification_type_key:,
          platform_enabled_channels: %w[email],
          **overrides,
        ),
      )
    end
  end

  context "with pending, failed, fresh, and done communications" do
    let(:pending_result) { accept.call(host_event_identity: "pending-1") }
    let(:failed_result) { accept.call(host_event_identity: "failed-1") }
    let(:fresh_result) { accept.call(host_event_identity: "fresh-1") }
    let(:done_result) { accept.call(host_event_identity: "done-1") }

    let(:pending_comm) { CommandTower::Messaging::Communication.find(pending_result.communication_id) }
    let(:failed_comm) { CommandTower::Messaging::Communication.find(failed_result.communication_id) }
    let(:fresh_comm) { CommandTower::Messaging::Communication.find(fresh_result.communication_id) }
    let(:done_comm) { CommandTower::Messaging::Communication.find(done_result.communication_id) }

    before do
      pending_result
      failed_result
      fresh_result
      done_result

      failed_comm.update_columns(
        execution_handoff_status: "failed",
        updated_at: 5.minutes.ago,
      )
      pending_comm.update_columns(updated_at: 5.minutes.ago)
      done_comm.update_columns(
        execution_handoff_status: "enqueued",
        updated_at: 5.minutes.ago,
      )

      clear_enqueued_jobs
    end

    it "re-enqueues HandoffJob for pending and failed communications past the grace window" do
      described_class.call(grace_window: 1.minute)

      expect(
        enqueued_jobs
          .select { |job| job[:job] == CommandTower::Messaging::HandoffJob }
          .map { |job| job[:args].first },
      ).to contain_exactly(pending_comm.id, failed_comm.id)
      expect(
        enqueued_jobs
          .select { |job| job[:job] == CommandTower::Messaging::HandoffJob }
          .map { |job| job[:args].first },
      ).not_to include(fresh_comm.id, done_comm.id)
    end
  end

  context "when recovery runs twice for the same communication" do
    let(:result) { accept.call }
    let(:communication) { CommandTower::Messaging::Communication.find(result.communication_id) }

    before do
      result
      communication.update_columns(updated_at: 5.minutes.ago)
      clear_enqueued_jobs
    end

    it "repeated recovery remains safe for the same communication" do
      described_class.call(grace_window: 1.minute)
      described_class.call(grace_window: 1.minute)

      expect(enqueued_jobs.count { |job| job[:job] == CommandTower::Messaging::HandoffJob }).to eq(2)

      perform_enqueued_jobs(only: CommandTower::Messaging::HandoffJob)
      expect(communication.reload.execution_handoff_status).to eq("enqueued")
      expect(CommandTower::Messaging::Communication.count).to eq(1)
    end
  end
end
