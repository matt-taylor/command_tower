# frozen_string_literal: true

RSpec.describe CommandTower::Clients::DecodedResponse do
  context "with payload and provider_metadata" do
    subject(:decoded) { described_class.new(payload: [ 1 ], provider_metadata: { pagination: :meta }) }

    it { expect(decoded.payload).to eq([ 1 ]) }
    it { expect(decoded.provider_metadata).to eq(pagination: :meta) }
  end

  context "without provider_metadata" do
    subject(:decoded) { described_class.new(payload: "raw") }

    it { expect(decoded.provider_metadata).to eq({}) }
  end
end
