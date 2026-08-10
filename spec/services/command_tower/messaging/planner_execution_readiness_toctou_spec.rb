# frozen_string_literal: true

RSpec.describe "Messaging Planner ∩ RecipientReadiness TOCTOU", :messaging_accept do
  let(:user) { create(:user, email_validated: true) }
  let(:notification_type_key) { "toctou.sms" }

  before do
    allow(
      CommandTower::Messaging::Execution::Adapters::Sms::Configuration,
    ).to receive(:sms_configured?).and_return(true)

    user.update!(phone_number: "+14155552671", phone_number_validated: true)

    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: notification_type_key,
        allowed_channels: %w[email sms],
        default_channels: %w[sms],
        inbox_available: false,
        user_configurable: true,
        mandatory: false,
        default_preference_state: {
          "channels" => { "email" => true, "sms" => true },
          "inbox" => false,
        },
      ),
    )
  end

  let(:accept_sms!) do
    CommandTower::Messaging::Accept::Coordinator.call(
      **default_accept_attrs(
        user:,
        notification_type_key:,
        host_event_identity: "toctou-#{SecureRandom.hex(4)}",
        platform_enabled_channels: %w[email sms],
      ),
    )
  end

  let(:queue_and_execute!) do
    lambda do |communication|
      delivery = communication.channel_deliveries.find_by!(channel_key: "sms")
      delivery.update!(status: "queued", execution_attempt_count: 0)
      adapter = CommandTower::Messaging::Execution::Adapters::FakeAdapter.new(outcome: :success)
      CommandTower::Workflows::Messaging::Execution::DeliverWorkflow.call(
        channel_delivery_id: delivery.id,
        executor: adapter,
      )
      [delivery.reload, adapter]
    end
  end

  context "when SMS is ready at plan and execute time" do
    let(:accept_result) { accept_sms! }
    let(:communication) { CommandTower::Messaging::Communication.find(accept_result.communication_id) }
    let(:execution) { queue_and_execute!.call(communication) }
    let(:delivery) { execution.first }
    let(:adapter) { execution.last }

    it "plans SMS when ready and executes successfully" do
      expect(communication.destination_plan.decision["platform_enabled_channels"]).to include("sms")
      expect(communication.channel_deliveries.map(&:channel_key)).to eq(%w[sms])
      expect(delivery.status).to eq("accepted_by_provider")
      expect(adapter.last_request.rendered.recipient_address).to eq("+14155552671")
    end
  end

  context "when phone becomes unverified after plan" do
    let(:accept_result) { accept_sms! }
    let(:communication) { CommandTower::Messaging::Communication.find(accept_result.communication_id) }

    before do
      accept_result
      user.update!(phone_number_validated: false)
    end

    let(:execution) { queue_and_execute!.call(communication) }
    let(:delivery) { execution.first }
    let(:adapter) { execution.last }

    it "fails terminal when phone becomes unverified after plan" do
      expect(delivery.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.error_code).to eq("recipient_unverified")
      expect(adapter.last_request).to be_nil
    end
  end

  context "when phone is cleared after plan" do
    let(:accept_result) { accept_sms! }
    let(:communication) { CommandTower::Messaging::Communication.find(accept_result.communication_id) }

    before do
      accept_result
      user.update!(phone_number: nil, phone_number_validated: false)
    end

    let(:execution) { queue_and_execute!.call(communication) }
    let(:delivery) { execution.first }
    let(:adapter) { execution.last }

    it "fails terminal when phone is cleared after plan" do
      expect(delivery.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.error_code).to eq("recipient_missing")
      expect(adapter.last_request).to be_nil
    end
  end

  context "when Accept-time platform enablement drops SMS before execute" do
    let(:accept_result) { accept_sms! }
    let(:communication) { CommandTower::Messaging::Communication.find(accept_result.communication_id) }

    before do
      plan = communication.destination_plan
      plan.update!(
        decision: plan.decision.merge("platform_enabled_channels" => %w[email]),
      )
    end

    let(:execution) { queue_and_execute!.call(communication) }
    let(:delivery) { execution.first }
    let(:adapter) { execution.last }

    it "fails terminal when Accept-time platform enablement drops SMS before execute" do
      expect(delivery.status).to eq("failed_terminal")
      expect(delivery.delivery_attempts.sole.error_code).to eq("platform_disabled")
      expect(adapter.last_request).to be_nil
    end
  end

  context "when recipient is not ready at plan time" do
    before { user.update!(phone_number_validated: false) }

    let(:accept_result) { accept_sms! }
    let(:communication) { CommandTower::Messaging::Communication.find(accept_result.communication_id) }

    it "excludes SMS at plan time when recipient is not ready" do
      expect(communication.channel_deliveries).to be_empty
      expect(
        communication.destination_plan.decision["excluded_destinations"].find do |row|
          row["destination"] == "sms"
        end["reason_class"],
      ).to eq("identity_unverified")
    end
  end
end
