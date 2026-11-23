# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::StatTile, :aggregate_failures do
  it "serializes" do
    expect(described_class.new(value: "42", label: "Spots left", tone: :accent, icon: "users").as_json).to eq(
      "type" => "stat_tile", "value" => "42", "label" => "Spots left", "tone" => "accent", "icon" => "users"
    )
  end

  it "omits optional fields" do
    expect(described_class.new(value: "42", label: "Spots").as_json.keys).to eq(%w[type value label])
  end

  CommandTower::UI::Tokens::TONE.each do |tone|
    it "accepts tone #{tone}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(value: "1", label: "x", tone: tone))).to eq([])
    end
  end

  it "requires value and label, and validates tone and icon" do
    expect(UiSpecHelpers.error_pairs(described_class.new(tone: "loud", icon: "Bad Icon")))
      .to contain_exactly(%i[value blank], %i[label blank], %i[tone inclusion], %i[icon invalid])
  end
end
