# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Communication, type: :model do
  subject(:communication) { described_class.create!(**params) }

  let(:params) do
    {
      user:,
      notification_type_key:,
      title:,
      body:,
      metadata:,
      execution_handoff_status: CommandTower::Messaging::Communication::HANDOFF_COMPLETE,
    }.compact
  end

  let(:user) { create(:user) }
  let(:notification_type_key) { "booking.success" }
  let(:title) { "Booking confirmed" }
  let(:body) { "Your booking was confirmed." }
  let(:metadata) { { "deep_link" => "/bookings/1" } }

  describe "persistence" do
    it "creates a communication for a recipient" do
      expect(communication).to be_persisted
      expect(communication.user).to eq(user)
      expect(communication.notification_type_key).to eq(notification_type_key)
      expect(communication.title).to eq(title)
      expect(communication.body).to eq(body)
      expect(communication.metadata).to eq(metadata)
    end
  end

  describe "associations" do
    it "belongs to user" do
      expect(communication.user).to eq(user)
    end

    context "with a destination plan" do
      let!(:plan) { create(:messaging_destination_plan, communication:) }

      it "has one destination plan" do
        expect(communication.reload.destination_plan).to eq(plan)
      end
    end

    context "with an inbox item" do
      let!(:inbox_item) { create(:messaging_inbox_item, communication:) }

      it "has one inbox item" do
        expect(communication.reload.inbox_item).to eq(inbox_item)
      end
    end

    context "with channel deliveries" do
      let!(:delivery) { create(:messaging_channel_delivery, communication:) }

      it "has many channel deliveries" do
        expect(communication.reload.channel_deliveries).to contain_exactly(delivery)
      end
    end

    context "when destroying dependent records" do
      let!(:plan) { create(:messaging_destination_plan, communication:) }

      it "destroys dependent destination plan" do
        expect { communication.destroy! }.to change(CommandTower::Messaging::DestinationPlan, :count).by(-1)
        expect { plan.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "validations" do
    context "when user is missing" do
      subject(:record) do
        described_class.new(
          notification_type_key:,
          title:,
          body:,
        )
      end

      it "requires a user" do
        expect(record).not_to be_valid
        expect(record.errors[:user]).to be_present
      end
    end

    context "when notification_type_key is missing" do
      subject(:record) { build(:messaging_communication, notification_type_key: nil) }

      it "requires notification_type_key" do
        expect(record).not_to be_valid
        expect(record.errors[:notification_type_key]).to be_present
      end
    end

    context "when title is missing" do
      subject(:record) { build(:messaging_communication, title: nil) }

      it "requires title" do
        expect(record).not_to be_valid
        expect(record.errors[:title]).to be_present
      end
    end

    context "when body is missing" do
      subject(:record) { build(:messaging_communication, body: nil) }

      it "requires body" do
        expect(record).not_to be_valid
        expect(record.errors[:body]).to be_present
      end
    end
  end

  describe "separation from legacy Message" do
    it "does not use a retired Message constant" do
      expect(described_class.name).not_to eq("Message")
      expect(defined?(Message)).to be_nil
    end
  end
end
