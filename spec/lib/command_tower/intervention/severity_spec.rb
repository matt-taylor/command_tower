# frozen_string_literal: true

RSpec.describe CommandTower::Intervention::Severity do
  it "exposes canonical severity strings" do
    expect(described_class::BLOCKING).to eq("blocking")
    expect(described_class::WARNING).to eq("warning")
    expect(described_class::INFORMATIONAL).to eq("informational")
    expect(described_class::ALL).to contain_exactly("blocking", "warning", "informational")
  end

  context "when serializing a warning blocker" do
    subject(:payload) do
      CommandTower::Serializers::Intervention::BlockerSerializer.serialize(
        code: "period_opens_later",
        action: "picks_period",
        title: "Week 1 opens soon",
        message: "Come back then to make your picks.",
        severity: described_class::WARNING
      )
    end

    it "round-trips warning through BlockerSerializer" do
      expect(payload[:severity]).to eq("warning")
    end
  end
end
