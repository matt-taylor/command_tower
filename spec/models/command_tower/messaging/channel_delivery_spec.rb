# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::ChannelDelivery, type: :model do
  subject(:channel_delivery) { create(:messaging_channel_delivery, communication:, channel_key:) }

  let(:communication) { create(:messaging_communication) }
  let(:channel_key) { "email" }

  describe "associations" do
    it "belongs to a communication" do
      expect(channel_delivery.communication).to eq(communication)
    end

    context "with delivery attempts" do
      let!(:attempt) { create(:messaging_delivery_attempt, channel_delivery:) }

      it "has many delivery attempts" do
        expect(channel_delivery.reload.delivery_attempts).to contain_exactly(attempt)
      end
    end

    context "when destroying dependent delivery attempts" do
      let!(:attempt) { create(:messaging_delivery_attempt, channel_delivery:) }

      it "destroys dependent delivery attempts" do
        expect { channel_delivery.destroy! }.to change(CommandTower::Messaging::DeliveryAttempt, :count).by(-1)
        expect { attempt.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "validations" do
    context "when channel_key is missing" do
      subject(:record) { build(:messaging_channel_delivery, channel_key: nil) }

      it "requires channel_key" do
        expect(record).not_to be_valid
        expect(record.errors[:channel_key]).to be_present
      end
    end
  end

  describe "multiple deliveries" do
    let!(:email) { create(:messaging_channel_delivery, communication:, channel_key: "email") }
    let!(:sms) { create(:messaging_channel_delivery, communication:, channel_key: "sms") }

    it "allows multiple channel deliveries on one communication" do
      expect(communication.reload.channel_deliveries).to contain_exactly(email, sms)
    end
  end
end
