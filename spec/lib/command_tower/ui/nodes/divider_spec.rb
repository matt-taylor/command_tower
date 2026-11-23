# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Divider, :aggregate_failures do
  it "serializes to its type only" do
    expect(described_class.new.as_json).to eq("type" => "divider")
  end

  it "is valid" do
    expect(UiSpecHelpers.error_pairs(described_class.new)).to eq([])
  end
end
