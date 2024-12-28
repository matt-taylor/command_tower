# frozen_string_literal: true

RSpec.describe ApiEngineBase::Jwt::Encode do
  let(:token) { ApiEngineBase::Jwt::Encode.(payload:, header:).token }
  let(:header) { { "header" => "value" } }
  let(:payload) { { "user" => "payload" } }

  describe ".call" do
    subject(:call) { described_class.(payload:, header:) }

    it do
      expect(call.success?).to eq true
    end

    it do
      expect(call.token).to be_a(String)
    end

    context "when header is nil" do
      let(:header) { nil }

      it do
        expect(call.success?).to eq true
      end

      it do
        expect(call.token).to be_a(String)
      end
    end
  end
end
