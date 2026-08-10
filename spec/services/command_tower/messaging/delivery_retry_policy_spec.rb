# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::DeliveryRetryPolicy do
  let(:build_delivery) do
    lambda do |status:, attempt_count:, updated_at: Time.current|
      communication = create(:messaging_communication)
      delivery = create(
        :messaging_channel_delivery,
        communication:,
        channel_key: "email",
        status:,
        execution_attempt_count: attempt_count,
      )
      delivery.update_columns(updated_at:)
      delivery.reload
    end
  end

  describe ".retries_exhausted?" do
    context "when failed_retryable at max attempts" do
      let(:delivery) do
        build_delivery.call(
          status: "failed_retryable",
          attempt_count: described_class::MAX_ATTEMPTS,
        )
      end

      it "is true" do
        expect(described_class.retries_exhausted?(delivery)).to be(true)
      end
    end

    context "when failed_retryable above max attempts" do
      let(:delivery) do
        build_delivery.call(
          status: "failed_retryable",
          attempt_count: described_class::MAX_ATTEMPTS + 1,
        )
      end

      it "is true" do
        expect(described_class.retries_exhausted?(delivery)).to be(true)
      end
    end

    context "when failed_retryable below max attempts" do
      let(:delivery) { build_delivery.call(status: "failed_retryable", attempt_count: 2) }

      it "is false" do
        expect(described_class.retries_exhausted?(delivery)).to be(false)
      end
    end

    context "when accepted_by_provider at max attempts" do
      let(:delivery) do
        build_delivery.call(
          status: "accepted_by_provider",
          attempt_count: described_class::MAX_ATTEMPTS,
        )
      end

      it "is false" do
        expect(described_class.retries_exhausted?(delivery)).to be(false)
      end
    end

    context "when failed_terminal at max attempts" do
      let(:delivery) do
        build_delivery.call(
          status: "failed_terminal",
          attempt_count: described_class::MAX_ATTEMPTS,
        )
      end

      it "is false" do
        expect(described_class.retries_exhausted?(delivery)).to be(false)
      end
    end
  end

  describe ".retry_expected?" do
    context "when failed_retryable below max attempts" do
      let(:delivery) { build_delivery.call(status: "failed_retryable", attempt_count: 2) }

      it "is true" do
        expect(described_class.retry_expected?(delivery)).to be(true)
      end
    end

    context "when retries are exhausted" do
      let(:delivery) do
        build_delivery.call(
          status: "failed_retryable",
          attempt_count: described_class::MAX_ATTEMPTS,
        )
      end

      it "is false" do
        expect(described_class.retry_expected?(delivery)).to be(false)
      end
    end

    context "when accepted_by_provider" do
      let(:delivery) { build_delivery.call(status: "accepted_by_provider", attempt_count: 1) }

      it "is false" do
        expect(described_class.retry_expected?(delivery)).to be(false)
      end
    end

    context "when failed_terminal" do
      let(:delivery) { build_delivery.call(status: "failed_terminal", attempt_count: 1) }

      it "is false" do
        expect(described_class.retry_expected?(delivery)).to be(false)
      end
    end

    %w[planned queued executing].each do |status|
      context "when #{status}" do
        let(:delivery) { build_delivery.call(status:, attempt_count: 1) }

        it "is false" do
          expect(described_class.retry_expected?(delivery)).to be(false)
        end
      end
    end
  end

  describe ".retry_eligible_at" do
    context "when retry is expected" do
      let(:updated_at) { Time.zone.parse("2026-07-24 12:00:00") }
      let(:delivery) do
        build_delivery.call(
          status: "failed_retryable",
          attempt_count: 2,
          updated_at:,
        )
      end

      it "returns updated_at + GRACE_WINDOW" do
        expect(described_class.retry_eligible_at(delivery)).to eq(
          updated_at + described_class::GRACE_WINDOW,
        )
      end
    end

    context "when retry is not expected" do
      let(:delivery) do
        build_delivery.call(
          status: "failed_retryable",
          attempt_count: described_class::MAX_ATTEMPTS,
        )
      end

      it "returns nil" do
        expect(described_class.retry_eligible_at(delivery)).to be_nil
      end
    end

    context "when status is non-retryable" do
      let(:delivery) { build_delivery.call(status: "queued", attempt_count: 0) }

      it "returns nil" do
        expect(described_class.retry_eligible_at(delivery)).to be_nil
      end
    end
  end
end
