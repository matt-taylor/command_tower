# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Endpoints::Validators::Push do
  describe ".validate!" do
    context "with an ExponentPushToken" do
      subject(:result) { described_class.validate!("ExponentPushToken[abc123]") }

      it "accepts Expo ExponentPushToken form" do
        expect(result.normalized_address).to eq("ExponentPushToken[abc123]")
        expect(result.masked_display_value).to eq("Device registered")
      end
    end

    context "with an ExpoPushToken" do
      subject(:result) { described_class.validate!("ExpoPushToken[xyz789]") }

      it "accepts ExpoPushToken form" do
        expect(result.normalized_address).to eq("ExpoPushToken[xyz789]")
      end
    end

    context "with a non-Expo string" do
      subject(:invoke) { described_class.validate!("random-device-token-long-enough") }

      it "rejects non-Expo tokens" do
        expect { invoke }.to raise_error(
          CommandTower::Messaging::Endpoints::ValidationError,
          /Expo push token/,
        )
      end
    end

    context "with a blank token" do
      subject(:invoke) { described_class.validate!("  ") }

      it "rejects blank tokens" do
        expect { invoke }.to raise_error(
          CommandTower::Messaging::Endpoints::ValidationError,
          /must be present/,
        )
      end
    end
  end
end
