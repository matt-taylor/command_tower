# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Contract::Communications do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe ".find" do
    subject(:find_result) { described_class.find(request) }

    let!(:communication) do
      create(:messaging_communication, :with_destination_plan, :with_inbox_item, user:)
    end
    let!(:channel_delivery) { create(:messaging_channel_delivery, communication:) }
    let!(:delivery_attempt) { create(:messaging_delivery_attempt, channel_delivery:) }

    let(:request) do
      CommandTower::Messaging::Contract::Requests::FindCommunication.build(
        communication_id: communication.id,
        recipient_id:,
      )
    end
    let(:recipient_id) { nil }

    context "when the communication exists" do
      let(:delivery) { find_result.channel_deliveries.first }
      let(:attempt) { delivery.delivery_attempts.first }

      it "returns the aggregate as a result DTO" do
        expect(find_result).to be_a(CommandTower::Messaging::Contract::Results::CommunicationResult)
        expect(find_result).not_to be_a(ActiveRecord::Base)
        expect(find_result.id).to eq(communication.id)
        expect(find_result.destination_plan).to be_a(
          CommandTower::Messaging::Contract::Results::DestinationPlanResult,
        )
        expect(find_result.destination_plan.id).to be_present
        expect(find_result.destination_plan).not_to be_a(ActiveRecord::Base)
        expect(find_result.inbox_item).to be_a(
          CommandTower::Messaging::Contract::Results::InboxItemResult,
        )
        expect(find_result.inbox_item.id).to be_present
        expect(find_result.inbox_item).not_to be_a(ActiveRecord::Base)
        expect(find_result.channel_deliveries.size).to eq(1)
        expect(delivery).to be_a(CommandTower::Messaging::Contract::Results::ChannelDeliveryResult)
        expect(delivery).not_to be_a(ActiveRecord::Base)
        expect(delivery.channel_key).to eq(channel_delivery.channel_key)
        expect(delivery.status).to eq(channel_delivery.status)
        expect(delivery.execution_attempt_count).to eq(channel_delivery.execution_attempt_count)
        expect(delivery.delivery_attempts.size).to eq(1)
        expect(attempt).to be_a(CommandTower::Messaging::Contract::Results::DeliveryAttemptResult)
        expect(attempt).not_to be_a(ActiveRecord::Base)
        expect(attempt.id).to eq(delivery_attempt.id)
        expect(attempt.status).to eq(delivery_attempt.status)
        expect(attempt.attempt_number).to eq(1)
        expect(attempt.started_at).to be_within(1.second).of(delivery_attempt.started_at)
      end
    end

    context "when delivery attempts need operational diagnostics" do
      before do
        channel_delivery.update!(
          status: CommandTower::Messaging::ChannelDelivery::STATUS_FAILED_RETRYABLE,
          execution_attempt_count: 2,
        )
        delivery_attempt.update!(
          status: "failed_retryable",
          started_at: 1.hour.ago,
          finished_at: 1.hour.ago + 5.seconds,
          error_code: "transient",
          provider_message_id: nil,
        )
      end

      let(:delivery) { find_result.channel_deliveries.first }

      it "exposes policy-derived retry fields without unsafe payload members" do
        expect(delivery.retry_expected).to be(true)
        expect(delivery.retries_exhausted).to be(false)
        expect(delivery.latest_outcome_code).to eq("transient")
        expect(delivery.latest_attempt_at).to be_within(1.second).of(delivery_attempt.reload.finished_at)
        expect(delivery.members).not_to include(:body, :metadata, :html)
        expect(delivery.delivery_attempts.first.members).not_to include(
          :body,
          :exception_message,
          :stack_trace,
          :sidekiq_jid,
        )
      end
    end

    context "when recipient_id matches" do
      let(:recipient_id) { user.id }

      it "returns the communication" do
        expect(find_result.id).to eq(communication.id)
      end
    end

    context "when recipient_id does not match" do
      let(:recipient_id) { other_user.id }

      it "raises NotFoundError" do
        expect { find_result }.to raise_error(CommandTower::Messaging::Contract::NotFoundError)
      end
    end

    context "when the communication does not exist" do
      let(:request) do
        CommandTower::Messaging::Contract::Requests::FindCommunication.build(
          communication_id: communication.id + 100_000,
        )
      end

      it "raises NotFoundError" do
        expect { find_result }.to raise_error(CommandTower::Messaging::Contract::NotFoundError)
      end
    end

    context "when communication_id is missing" do
      let(:request) do
        CommandTower::Messaging::Contract::Requests::FindCommunication.build(communication_id: nil)
      end

      it "raises ValidationError" do
        expect { find_result }.to raise_error(CommandTower::Messaging::Contract::ValidationError)
      end
    end

    context "when the request object type is wrong" do
      let(:request) { Object.new }

      it "raises ValidationError" do
        expect { find_result }.to raise_error(CommandTower::Messaging::Contract::ValidationError)
      end
    end
  end
end
