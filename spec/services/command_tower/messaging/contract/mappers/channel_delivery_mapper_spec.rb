# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Contract::Mappers::ChannelDeliveryMapper do
  UNSAFE_MEMBERS = %i[
    body
    html
    html_body
    metadata
    recipient_email
    email
    raw_provider_payload
    provider_response
    exception_message
    message
    stack_trace
    backtrace
    credentials
    token
    tokens
    sidekiq_jid
    jid
    source
  ].freeze

  let(:create_delivery) do
    lambda do |attrs = {}|
      communication = create(:messaging_communication)
      create(
        :messaging_channel_delivery,
        {
          communication:,
          channel_key: "email",
          status: CommandTower::Messaging::ChannelDelivery::STATUS_QUEUED,
          execution_attempt_count: 0,
        }.merge(attrs),
      )
    end
  end

  describe ".to_result" do
    context "when mapping operational fields with no attempts" do
      let(:delivery) do
        record = create_delivery.call(
          status: CommandTower::Messaging::ChannelDelivery::STATUS_FAILED_RETRYABLE,
          execution_attempt_count: 2,
        )
        record.update_columns(updated_at: Time.zone.parse("2026-07-24 10:00:00"))
        record.reload
      end

      subject(:result) { described_class.to_result(delivery) }

      it "maps delivery operational fields and empty attempts" do
        expect(result.id).to eq(delivery.id)
        expect(result.channel_key).to eq("email")
        expect(result.status).to eq("failed_retryable")
        expect(result.execution_attempt_count).to eq(2)
        expect(result.terminal).to be(false)
        expect(result.retries_exhausted).to be(false)
        expect(result.retry_expected).to be(true)
        expect(result.retry_eligible_at).to eq(
          delivery.updated_at + CommandTower::Messaging::DeliveryRetryPolicy::GRACE_WINDOW,
        )
        expect(result.latest_outcome_code).to be_nil
        expect(result.latest_attempt_at).to be_nil
        expect(result.delivery_attempts).to eq([])
      end
    end

    context "when multiple attempts exist" do
      let(:delivery) { create_delivery.call }
      let!(:older) do
        create(
          :messaging_delivery_attempt,
          channel_delivery: delivery,
          status: "failed_retryable",
          started_at: 2.hours.ago,
          finished_at: 2.hours.ago + 1.second,
          error_code: "older",
        )
      end
      let!(:newer) do
        create(
          :messaging_delivery_attempt,
          channel_delivery: delivery,
          status: "succeeded",
          started_at: 1.hour.ago,
          finished_at: 1.hour.ago + 1.second,
          normalized_provider_status: "accepted",
          provider_message_id: "prov-1",
        )
      end
      let!(:same_time) do
        create(
          :messaging_delivery_attempt,
          channel_delivery: delivery,
          status: "failed_retryable",
          started_at: older.started_at,
          finished_at: older.finished_at,
          error_code: "same_time",
        )
      end

      subject(:result) { described_class.to_result(delivery.reload) }

      it "orders attempts started_at ASC, id ASC and assigns attempt_number" do
        expect(result.delivery_attempts.map { |a| [a.id, a.attempt_number] }).to eq(
          [
            [older.id, 1],
            [same_time.id, 2],
            [newer.id, 3],
          ],
        )
        expect(result.latest_outcome_code).to eq("accepted")
        expect(result.latest_attempt_at).to eq(newer.finished_at)
        expect(result.delivery_attempts.last.provider_message_id).to eq("prov-1")
      end
    end

    context "when error_code and normalized_provider_status both exist" do
      let(:delivery) { create_delivery.call }

      before do
        create(
          :messaging_delivery_attempt,
          channel_delivery: delivery,
          status: "failed_retryable",
          started_at: 1.hour.ago,
          finished_at: 1.hour.ago + 1.second,
          error_code: "smtp_timeout",
          normalized_provider_status: "accepted",
        )
      end

      subject(:result) { described_class.to_result(delivery.reload) }

      it "prefers error_code over normalized_provider_status for latest_outcome_code" do
        expect(result.latest_outcome_code).to eq("smtp_timeout")
      end
    end

    context "when finished_at is nil" do
      let(:started) { 30.minutes.ago }
      let(:delivery) { create_delivery.call }

      before do
        create(
          :messaging_delivery_attempt,
          channel_delivery: delivery,
          status: "started",
          started_at: started,
          finished_at: nil,
        )
      end

      subject(:result) { described_class.to_result(delivery.reload) }

      it "uses started_at for latest_attempt_at" do
        expect(result.latest_attempt_at).to be_within(1.second).of(started)
      end
    end

    context "when retryable delivery is exhausted" do
      let(:delivery) do
        create_delivery.call(
          status: CommandTower::Messaging::ChannelDelivery::STATUS_FAILED_RETRYABLE,
          execution_attempt_count: CommandTower::Messaging::DeliveryRetryPolicy::MAX_ATTEMPTS,
        )
      end

      before do
        create(
          :messaging_delivery_attempt,
          channel_delivery: delivery,
          status: "failed_retryable",
          started_at: 1.hour.ago,
          finished_at: 1.hour.ago + 1.second,
          error_code: "transient",
        )
      end

      subject(:result) { described_class.to_result(delivery.reload) }

      it "marks exhausted retryable deliveries without expecting another retry" do
        expect(result.retries_exhausted).to be(true)
        expect(result.retry_expected).to be(false)
        expect(result.retry_eligible_at).to be_nil
        expect(result.terminal).to be(false)
        expect(result.execution_attempt_count).to eq(
          CommandTower::Messaging::DeliveryRetryPolicy::MAX_ATTEMPTS,
        )
        expect(result.delivery_attempts.size).to eq(1)
      end
    end

    context "when delivery is accepted by provider" do
      let(:delivery) do
        create_delivery.call(
          status: CommandTower::Messaging::ChannelDelivery::STATUS_ACCEPTED_BY_PROVIDER,
          execution_attempt_count: 1,
        )
      end

      before do
        create(
          :messaging_delivery_attempt,
          channel_delivery: delivery,
          status: "succeeded",
          started_at: 1.hour.ago,
          finished_at: 1.hour.ago + 1.second,
          normalized_provider_status: "accepted",
          provider_message_id: nil,
        )
      end

      subject(:result) { described_class.to_result(delivery.reload) }

      it "marks accepted deliveries as terminal without retry expectation" do
        expect(result.terminal).to be(true)
        expect(result.retry_expected).to be(false)
        expect(result.retries_exhausted).to be(false)
        expect(result.delivery_attempts.first.provider_message_id).to be_nil
      end
    end

    context "when delivery failed terminally" do
      let(:delivery) do
        create_delivery.call(
          status: CommandTower::Messaging::ChannelDelivery::STATUS_FAILED_TERMINAL,
          execution_attempt_count: 1,
        )
      end

      before do
        create(
          :messaging_delivery_attempt,
          channel_delivery: delivery,
          status: "failed_terminal",
          started_at: 1.hour.ago,
          finished_at: 1.hour.ago + 1.second,
          error_code: "adapter_unconfigured",
        )
      end

      subject(:result) { described_class.to_result(delivery.reload) }

      it "marks failed_terminal deliveries as terminal" do
        expect(result.terminal).to be(true)
        expect(result.retry_expected).to be(false)
        expect(result.latest_outcome_code).to eq("adapter_unconfigured")
      end
    end

    context "when checking contract safety" do
      let(:delivery) do
        create_delivery.call(
          status: CommandTower::Messaging::ChannelDelivery::STATUS_FAILED_RETRYABLE,
          execution_attempt_count: 1,
        )
      end

      before do
        create(
          :messaging_delivery_attempt,
          channel_delivery: delivery,
          status: "failed_retryable",
          started_at: 1.hour.ago,
          finished_at: 1.hour.ago + 1.second,
          error_code: "transient",
          error_class: "RuntimeError",
          provider_message_id: "opaque-id",
        )
      end

      subject(:result) { described_class.to_result(delivery.reload) }

      it "does not expose unsafe members on delivery or attempt results" do
        expect(result.members & UNSAFE_MEMBERS).to eq([])
        expect(result.delivery_attempts.first.members & UNSAFE_MEMBERS).to eq([])
        expect(result.delivery_attempts.first.error_class).to eq("RuntimeError")
        expect(result.delivery_attempts.first.provider_message_id).to eq("opaque-id")
      end
    end
  end
end
