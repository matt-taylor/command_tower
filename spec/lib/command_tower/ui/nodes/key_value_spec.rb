# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::KeyValue, :aggregate_failures do
  let(:instant) { CommandTower::UI::Nodes::Instant.new(at: "2025-12-04T14:00:00Z", zone: "UTC") }
  let(:bad_items) { described_class.new(items: [{ icon: "Bad Icon!", value: 5 }, { label: "x" }]) }
  let(:bad_instant) { CommandTower::UI::Nodes::Instant.new(at: "x", zone: "UTC") }

  it "serializes items from hashes" do
    expect(described_class.new(items: [{ icon: "calendar", label: "When", value: "Tonight" }, { value: "x" }]).as_json)
      .to eq("type" => "key_value",
             "items" => [{ "icon" => "calendar", "label" => "When", "value" => "Tonight" }, { "value" => "x" }])
  end

  it "serializes a time value" do
    expect(described_class.new(items: [{ label: "Starts", value: instant }]).as_json["items"].first["value"])
      .to include("type" => "time", "zone" => "UTC")
  end

  it "needs at least one item (G7)" do
    expect(UiSpecHelpers.error_pairs(described_class.new)).to eq([%i[items blank]])
  end

  it "caps items" do
    expect(UiSpecHelpers.error_pairs(described_class.new(items: Array.new(51) { { value: "v" } })))
      .to eq([%i[items too_many_items]])
  end

  it "rejects non-item entries" do
    expect(UiSpecHelpers.error_pairs(described_class.new(items: ["x"]))).to eq([%i[items invalid_child]])
  end

  it "validates item values and icons at item paths" do
    expect(UiSpecHelpers.document(bad_items).validation_errors).to contain_exactly(
      { path: "root.items[0].icon", code: "invalid" },
      { path: "root.items[0].value", code: "invalid" },
      { path: "root.items[1].value", code: "blank" }
    )
  end

  it "validates a time value inside an item" do
    expect(UiSpecHelpers.document(described_class.new(items: [{ value: bad_instant }])).validation_errors)
      .to eq([{ path: "root.items[0].value.at", code: "invalid" }])
  end
end
