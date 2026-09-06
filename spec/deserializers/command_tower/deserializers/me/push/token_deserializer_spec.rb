# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Me::Push::TokenDeserializer do
  describe ".call" do
    context "with snake_case token" do
      subject(:result) { described_class.call(token: "ExponentPushToken[deser01]") }

      it "extracts the address" do
        expect(result).to be_success
        expect(result.input.address).to eq("ExponentPushToken[deser01]")
      end
    end

    context "with camelCase address" do
      subject(:result) { described_class.call("address" => "ExpoPushToken[deser02]") }

      it "accepts address as an alias" do
        expect(result).to be_success
        expect(result.input.address).to eq("ExpoPushToken[deser02]")
      end
    end

    context "with a blank token" do
      subject(:result) { described_class.call(token: "") }

      it "fails" do
        expect(result).to be_failure
      end
    end

    context "with a non-Expo token" do
      subject(:result) { described_class.call(token: "plain-device-token-string") }

      it "fails" do
        expect(result).to be_failure
      end
    end
  end
end
