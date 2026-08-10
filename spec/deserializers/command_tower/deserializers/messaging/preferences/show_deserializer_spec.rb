# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Messaging::Preferences::ShowDeserializer do
  describe "#call" do
    context "with empty trusted input" do
      subject(:result) { described_class.call({}) }

      it { expect(result).to be_success }
      it { expect(result.input).to be_a(described_class::Input) }
    end

    context "with unrelated params" do
      subject(:result) { described_class.call({ limit: 10, unexpected: "value" }) }

      it { expect(result).to be_success }
    end
  end
end
