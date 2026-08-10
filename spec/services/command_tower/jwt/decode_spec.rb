# frozen_string_literal: true

RSpec.describe CommandTower::Jwt::Decode do
  let(:token) { CommandTower::Jwt::Encode.(payload:, header:) }
  let(:header) { { "header" => "value" } }
  let(:payload) { { "user" => "payload" } }

  describe ".call" do
    subject(:call) { described_class.(token:) }

    it "success" do
      expect(call.success?).to eq(true)
    end

    it "is not a failure" do
      expect(call.failure?).to eq(false)
    end

    it "returns payload" do
      expect(call.payload).to eq(payload)
    end

    it "returns payload with indifferent access" do
      expect(call.payload[:user]).to eq("payload")
    end

    it "returns header" do
      expect(call.headers).to include(header)
    end

    context "with invalid token" do
      let(:token) { "this is not a jwt token" }

      it "fails" do
        expect(call.success?).to eq(false)
      end

      it "is a failure" do
        expect(call.failure?).to eq(true)
      end

      it "sets failure message" do
        expect(call.msg).to eq("Invalid Token")
      end

      it "has no payload" do
        expect(call.payload).to be_nil
      end
    end
  end
end
