# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Messaging::Handoff::ProcessWorkflow, :messaging_accept do
  let(:user) { create(:user) }
  let(:notification_type_key) { "booking.success" }
  let(:platform_enabled_channels) { %w[email sms] }

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
      CommandTower::Messaging::Accept::Coordinator.call(
        **default_accept_attrs(user:, notification_type_key:, platform_enabled_channels:, **overrides),
      )
    end
  end

  let(:communication_for) do
    lambda do |result|
      CommandTower::Messaging::Communication.find(result.communication_id)
    end
  end

  describe "channel plans" do
    before do
      allow(
        CommandTower::Messaging::Execution::Adapters::Sms::Configuration,
      ).to receive(:sms_configured?).and_return(true)
      user.update!(phone_number: "+14155552671", phone_number_validated: true)
    end

    let(:accept_result) { accept.call(message_overrides: { "channels_add" => %w[sms] }) }
    let(:communication) { communication_for.call(accept_result) }

    subject(:invoke) { described_class.call(communication_id: communication.id) }

    it "transitions planned channel deliveries to queued and marks handoff enqueued" do
      expect(communication.execution_handoff_status).to eq("pending")
      expect(communication.channel_deliveries.pluck(:status).uniq).to eq(["planned"])

      invoke
      communication.reload

      expect(communication.execution_handoff_status).to eq("enqueued")
      expect(communication.channel_deliveries.pluck(:status).uniq).to eq(["queued"])
      expect(CommandTower::Messaging::DeliveryAttempt.count).to eq(0)
    end
  end

  describe "inbox-only and empty optional plans" do
    context "when inbox-only with no channel deliveries" do
      before do
        upsert_notification_preference!(
          recipient_id: user.id,
          notification_type_key:,
          preference_state: build_preference_state(
            channels: { "email" => false, "sms" => false },
            inbox: true,
          ),
        )
      end

      let(:accept_result) { accept.call }

      subject(:invoke) { described_class.call(communication_id: accept_result.communication_id) }

      before { invoke }

      let(:communication) { communication_for.call(accept_result).reload }

      it "marks handoff complete for inbox-only with no channel deliveries" do
        expect(communication.execution_handoff_status).to eq("complete")
        expect(communication.channel_deliveries).to be_empty
        expect(communication.inbox_item).to be_present
      end
    end

    context "when the plan is an empty optional plan" do
      before do
        upsert_notification_preference!(
          recipient_id: user.id,
          notification_type_key:,
          preference_state: build_preference_state(
            channels: { "email" => false, "sms" => false },
            inbox: false,
          ),
        )
      end

      let(:accept_result) { accept.call }

      subject(:invoke) { described_class.call(communication_id: accept_result.communication_id) }

      before { invoke }

      it "marks handoff complete for an empty optional plan" do
        expect(communication_for.call(accept_result).reload.execution_handoff_status).to eq("complete")
        expect(CommandTower::Messaging::ChannelDelivery.count).to eq(0)
      end
    end
  end

  describe "idempotency" do
    context "when already enqueued" do
      let(:accept_result) { accept.call }
      let(:communication) { communication_for.call(accept_result) }

      before do
        described_class.call(communication_id: communication.id)
        communication.reload
      end

      subject(:invoke) { described_class.call(communication_id: communication.id) }

      it "is a no-op when already enqueued" do
        expect(communication.execution_handoff_status).to eq("enqueued")

        expect { invoke }.not_to(change { communication.reload.updated_at })
        expect(communication.channel_deliveries.pluck(:status).uniq).to eq(["queued"])
      end
    end

    context "when already complete" do
      before do
        upsert_notification_preference!(
          recipient_id: user.id,
          notification_type_key:,
          preference_state: build_preference_state(
            channels: { "email" => false, "sms" => false },
            inbox: false,
          ),
        )
      end

      let(:accept_result) { accept.call }
      let(:communication) { communication_for.call(accept_result) }

      before do
        described_class.call(communication_id: communication.id)
        communication.reload
      end

      subject(:invoke) { described_class.call(communication_id: communication.id) }

      it "is a no-op when already complete" do
        expect(communication.execution_handoff_status).to eq("complete")
        expect { invoke }.not_to(change { communication.reload.updated_at })
      end
    end
  end

  describe "execution failure" do
    before do
      allow(CommandTower::Messaging::Handoff::AdvanceCommunication)
        .to receive(:call)
        .and_raise(ActiveRecord::RecordInvalid.new(CommandTower::Messaging::ChannelDelivery.new))
    end

    context "when handoff processing fails" do
      let(:accept_result) { accept.call }
      let(:communication) { communication_for.call(accept_result) }

      subject(:workflow_result) { described_class.call(communication_id: communication.id) }

      it "marks handoff failed and returns a job-propagating failure" do
        expect(workflow_result).to be_failure
        expect(workflow_result.meta[:propagate_to_job]).to eq(true)
        expect(communication.reload.execution_handoff_status).to eq("failed")
      end
    end

    context "when invoked from a job" do
      let(:accept_result) { accept.call }
      let(:communication) { communication_for.call(accept_result) }

      subject(:invoke) { described_class.call_from_job(communication_id: communication.id) }

      it "raises through call_from_job for ActiveJob observability" do
        expect { invoke }.to raise_error(CommandTower::Errors::InternalError)
      end
    end
  end

  describe "missing communication" do
    subject(:workflow_result) { described_class.call(communication_id: -1) }

    it "returns success noop without raising" do
      expect(workflow_result).to be_success
      expect(workflow_result.payload[:outcome]).to eq(:noop)
    end
  end
end
