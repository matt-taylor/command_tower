# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Badge, :aggregate_failures do
  it "serializes" do
    expect(described_class.new(label: "New", tone: :success).as_json)
      .to eq("type" => "badge", "label" => "New", "tone" => "success")
  end

  it "defaults the tone to neutral" do
    expect(described_class.new(label: "New").tone).to eq("neutral")
  end

  CommandTower::UI::Tokens::TONE.each do |tone|
    it "accepts tone #{tone}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(label: "x", tone: tone))).to eq([])
    end
  end

  it "requires a label and a known tone" do
    expect(UiSpecHelpers.error_pairs(described_class.new(label: "", tone: "loud")))
      .to contain_exactly(%i[label blank], %i[tone inclusion])
  end
end
