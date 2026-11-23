# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Banner, :aggregate_failures do
  it "serializes" do
    expect(described_class.new(tone: :warning, title: "Heads up", spans: ["Careful"]).as_json).to eq(
      "type" => "banner", "tone" => "warning", "title" => "Heads up",
      "spans" => [{ "type" => "text", "text" => "Careful" }]
    )
  end

  CommandTower::UI::Tokens::TONE.each do |tone|
    it "accepts tone #{tone}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(tone: tone, spans: ["x"]))).to eq([])
    end
  end

  it "rejects unknown tones and empty spans" do
    expect(UiSpecHelpers.error_pairs(described_class.new(tone: "loud")))
      .to contain_exactly(%i[tone inclusion], %i[spans blank])
  end
end
