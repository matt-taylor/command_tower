# frozen_string_literal: true

RSpec.describe ApiEngineBase::Jwt::Decode do
  let(:token) { ApiEngineBase::Jwt::Encode.(payload:, header:).token }
  let(:header) { { "header" => "value" } }
  let(:payload) { { "user" => "payload" } }

  describe ".call" do
    subject(:call) { described_class.(token:) }

    it "success" do
      expect(call.success?).to eq(true)
    end

    it "returns payload" do
      expect(call.payload).to eq(payload)
    end

    it "returns header" do
      expect(call.headers).to include(header)
    end

    context "with invalid token" do
      let(:token) { "this is not a jwt token" }

      it "fails" do
        expect(call.success?).to eq(false)
      end
    end
  end
end
