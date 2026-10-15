# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::DeliveryAttempt, type: :model do
  subject(:delivery_attempt) { create(:messaging_delivery_attempt, channel_delivery:) }

  let(:channel_delivery) { create(:messaging_channel_delivery) }

  describe "associations" do
    it "belongs to a channel delivery" do
      expect(delivery_attempt.channel_delivery).to eq(channel_delivery)
    end
  end

  describe "provider_metadata JSON casting" do
    let(:expo_metadata) do
      {
        "expo" => {
          "endpoints" => [
            {
              "endpoint_id" => 3,
              "ticket_id" => "t-1",
              "ticket_status" => "ok",
              "receipt_status" => "pending",
            },
          ],
        },
      }
    end

    subject(:provider_metadata_caster) { described_class.type_for_attribute(:provider_metadata) }

    it "uses the JSON attribute caster" do
      expect(provider_metadata_caster.type).to eq(:json)
    end

    let(:delivery_attempt_model_source) do
      File.read(CommandTower::Engine.root.join("app/models/command_tower/messaging/delivery_attempt.rb"))
    end

    it "declares an explicit JSON caster in the model source" do
      expect(delivery_attempt_model_source).to include("attribute :provider_metadata, :json")
    end

    context "when persisting expo metadata" do
      before { delivery_attempt.update!(provider_metadata: expo_metadata) }

      it "round-trips a Hash through reload and stores valid JSON in the database" do
        delivery_attempt.reload
        expect(delivery_attempt.provider_metadata).to eq(expo_metadata)

        raw = ActiveRecord::Base.connection.select_value(
          ActiveRecord::Base.sanitize_sql_array(
            ["SELECT provider_metadata FROM messaging_delivery_attempts WHERE id = ?", delivery_attempt.id],
          ),
        )
        expect(raw).to be_a(String)
        expect(raw).not_to include("=>")
        expect(JSON.parse(raw)).to eq(expo_metadata)
      end
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
