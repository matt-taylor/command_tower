# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Component, :aggregate_failures do
  let(:fallback) { UiSpecHelpers.text("Fallback") }
  let(:bad_fallback) { CommandTower::UI::Nodes::Badge.new(label: "x", tone: "loud") }

  it "serializes with its fallback tree" do # rubocop:disable RSpec/ExampleLength
    expect(
      described_class.new(key: "pickem.make_picks", variant: "compact", data: { week: 3 }, fallback: fallback).as_json
    ).to eq(
      "type" => "component", "key" => "pickem.make_picks", "variant" => "compact", "data" => { "week" => 3 },
      "fallback" => fallback.as_json
    )
  end

  it "defaults data to an empty object" do
    expect(described_class.new(key: "a.b", fallback: fallback).as_json["data"]).to eq({})
  end

  it "requires a registered-style key" do
    expect(UiSpecHelpers.error_pairs(described_class.new(key: "Bad Key", fallback: fallback)))
      .to eq([%i[key invalid]])
  end

  it "requires a fallback node and hash data" do
    expect(UiSpecHelpers.error_pairs(described_class.new(key: "a.b", data: [], fallback: "text")))
      .to contain_exactly(%i[data invalid], %i[fallback invalid_child])
  end

  it "validates the fallback tree at its path" do
    expect(UiSpecHelpers.document(described_class.new(key: "a.b", fallback: bad_fallback)).validation_errors)
      .to eq([{ path: "root.fallback.tone", code: "inclusion" }])
  end
end
