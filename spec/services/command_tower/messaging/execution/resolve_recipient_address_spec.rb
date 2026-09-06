# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Execution::ResolveRecipientAddress do
  let(:user) { instance_double(User, email: "a@example.com", phone_number: "+14155552671") }
  let(:communication) { instance_double(CommandTower::Messaging::Communication, user:) }

  describe ".call" do
    context "when channel is push with no eligible endpoints" do
      let(:readiness) do
        instance_double(
          CommandTower::Messaging::RecipientReadiness::ChannelResult,
          eligible_endpoint_ids: [],
        )
      end

      subject(:result) do
        described_class.call(communication:, channel_key: "push", readiness_result: readiness)
      end

      it "returns recipient_missing" do
        expect(result).to eq(address: nil, error_code: "recipient_missing")
      end
    end

    context "when channel is push with one eligible endpoint" do
      let(:readiness) do
        instance_double(
          CommandTower::Messaging::RecipientReadiness::ChannelResult,
          eligible_endpoint_ids: [42],
        )
      end

      subject(:result) do
        described_class.call(communication:, channel_key: "push", readiness_result: readiness)
      end

      it "uses the first eligible endpoint id as the opaque address" do
        expect(result).to eq(address: "42", error_code: nil)
      end
    end

    context "when channel is push with multiple eligible endpoints" do
      let(:readiness) do
        instance_double(
          CommandTower::Messaging::RecipientReadiness::ChannelResult,
          eligible_endpoint_ids: [7, 8, 9],
        )
      end

      subject(:result) do
        described_class.call(communication:, channel_key: "push", readiness_result: readiness)
      end

      it "does not treat multi-id fan-out as missing and uses the first id for render" do
        expect(result).to eq(address: "7", error_code: nil)
      end
    end
  end
end
