# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Stack, :aggregate_failures do
  it "serializes with defaults, omitting absent align" do
    expect(described_class.new.as_json).to eq("type" => "stack", "gap" => "md", "children" => [])
  end

  it "serializes children recursively" do
    expect(described_class.new(gap: :sm, align: :between, children: [UiSpecHelpers.divider]).as_json).to eq(
      "type" => "stack", "gap" => "sm", "align" => "between", "children" => [{ "type" => "divider" }]
    )
  end

  CommandTower::UI::Tokens::GAP.each do |gap|
    it "accepts gap #{gap}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(gap: gap))).to eq([])
    end
  end

  CommandTower::UI::Tokens::ALIGN.each do |align|
    it "accepts align #{align}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(align: align))).to eq([])
    end
  end

  it "rejects unknown tokens" do
    expect(UiSpecHelpers.error_pairs(described_class.new(gap: "huge", align: "stretch")))
      .to contain_exactly(%i[gap inclusion], %i[align inclusion])
  end

  it "rejects children that are not nodes" do
    expect(UiSpecHelpers.error_pairs(described_class.new(children: ["text"]))).to eq([%i[children invalid_child]])
  end

  it "rejects unknown attributes" do
    expect { described_class.new(direction: "row") }.to raise_error(ActiveModel::UnknownAttributeError)
  end
end
