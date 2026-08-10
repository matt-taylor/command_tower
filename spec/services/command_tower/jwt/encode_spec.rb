# frozen_string_literal: true

RSpec.describe CommandTower::Jwt::Encode do
  let(:header) { { "header" => "value" } }
  let(:payload) { { "user" => "payload" } }

  describe ".call" do
    subject(:call) { described_class.(payload:, header:) }

    it "returns the encoded token" do
      expect(call).to be_a(String)
    end

    it "encodes a token that decodes back to the payload" do
      expect(CommandTower::Jwt::Decode.(token: call).payload).to eq(payload)
    end

    context "when header is nil" do
      let(:header) { nil }

      it "returns the encoded token" do
        expect(call).to be_a(String)
      end
    end
  end
end
