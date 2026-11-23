# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Card, :aggregate_failures do
  let(:divider) { UiSpecHelpers.divider }

  it "serializes defaults" do
    expect(described_class.new.as_json).to eq(
      "type" => "card", "surface" => "raised", "padding" => "md", "children" => []
    )
  end

  it "serializes tone and nested children" do
    expect(described_class.new(surface: :tinted, tone: :warning, padding: :lg, children: [divider]).as_json)
      .to include("surface" => "tinted", "tone" => "warning", "padding" => "lg")
  end

  CommandTower::UI::Tokens::SURFACE.each do |surface|
    it "accepts surface #{surface}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(surface: surface))).to eq([])
    end
  end

  CommandTower::UI::Tokens::TONE.each do |tone|
    it "accepts tone #{tone}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(tone: tone))).to eq([])
    end
  end

  it "rejects unknown tokens" do
    expect(UiSpecHelpers.error_pairs(described_class.new(surface: "glass", tone: "loud", padding: "huge")))
      .to contain_exactly(%i[surface inclusion], %i[tone inclusion], %i[padding inclusion])
  end
end
