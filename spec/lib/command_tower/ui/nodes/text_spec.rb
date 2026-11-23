# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Text, :aggregate_failures do
  let(:bold_span) { CommandTower::UI::Nodes::Span.new(text: "bold", strong: true) }
  let(:link_span) { CommandTower::UI::Nodes::Span.link("More", action: UiSpecHelpers.navigate("/more")) }
  let(:mixed_spans) { described_class.new(spans: ["Plain ", bold_span, link_span]).as_json["spans"] }

  it "serializes camelCase keys with snake_case token values" do # rubocop:disable RSpec/ExampleLength
    expect(
      described_class.new(variant: :heading_xl, text_tone: :secondary, max_lines: 2, spans: ["Hello"]).as_json
    ).to eq(
      "type" => "text", "variant" => "heading_xl", "textTone" => "secondary", "maxLines" => 2,
      "spans" => [{ "type" => "text", "text" => "Hello" }]
    )
  end

  it "coerces strings to text spans and keeps explicit spans" do
    expect(mixed_spans.pluck("type")).to eq(%w[text text link])
    expect(mixed_spans[1]).to include("strong" => true)
  end

  CommandTower::UI::Tokens::VARIANT.each do |variant|
    it "accepts variant #{variant}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(variant: variant, spans: ["x"]))).to eq([])
    end
  end

  CommandTower::UI::Tokens::TEXT_TONE.each do |tone|
    it "accepts textTone #{tone}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(text_tone: tone, spans: ["x"]))).to eq([])
    end
  end

  %w[success warning danger neutral loud].each do |tone|
    it "rejects textTone #{tone} (council A2)" do
      expect(UiSpecHelpers.error_pairs(described_class.new(text_tone: tone, spans: ["x"])))
        .to eq([%i[text_tone inclusion]])
    end
  end

  it "requires at least one span" do
    expect(UiSpecHelpers.error_pairs(described_class.new)).to eq([%i[spans blank]])
  end

  it "rejects non-span entries" do
    expect(UiSpecHelpers.error_pairs(described_class.new(spans: [1]))).to eq([%i[spans invalid_child]])
  end

  it "caps spans per text" do
    expect(UiSpecHelpers.error_pairs(described_class.new(spans: Array.new(51) { "a" })))
      .to eq([%i[spans too_many_spans]])
  end

  it "validates maxLines" do
    expect(UiSpecHelpers.error_pairs(described_class.new(spans: ["x"], max_lines: 0)))
      .to eq([%i[max_lines greater_than]])
  end
end
