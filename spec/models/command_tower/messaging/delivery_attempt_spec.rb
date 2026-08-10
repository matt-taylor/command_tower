# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::DeliveryAttempt, type: :model do
  subject(:delivery_attempt) { create(:messaging_delivery_attempt, channel_delivery:) }

  let(:channel_delivery) { create(:messaging_channel_delivery) }

  describe "associations" do
    it "belongs to a channel delivery" do
      expect(delivery_attempt.channel_delivery).to eq(channel_delivery)
    end
  end

  describe "multiple attempts" do
    context "with two attempts under one delivery" do
      let!(:first) { create(:messaging_delivery_attempt, channel_delivery:) }
      let!(:second) { create(:messaging_delivery_attempt, channel_delivery:) }

      it "allows multiple attempts under one delivery" do
        expect(channel_delivery.reload.delivery_attempts).to contain_exactly(first, second)
      end
    end

    context "when recording an attempt" do
      let(:communication) { channel_delivery.communication }

      before { delivery_attempt }

      it "does not create a new communication when recording an attempt" do
        expect { create(:messaging_delivery_attempt, channel_delivery:) }
          .not_to change(CommandTower::Messaging::Communication, :count)
        expect(delivery_attempt.channel_delivery.communication).to eq(communication)
      end
    end
  end
end
