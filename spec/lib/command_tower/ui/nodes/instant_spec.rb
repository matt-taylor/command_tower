# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Instant, :aggregate_failures do
  let(:attrs) { { at: "2025-12-04T14:00:00Z", zone: "America/Los_Angeles" } }

  it "uses wire type time and a class name that does not shadow ::Time" do
    expect(described_class.new(**attrs).as_json["type"]).to eq("time")
    expect(described_class.name).to eq("CommandTower::UI::Nodes::Instant")
    expect(CommandTower::UI::Nodes.const_defined?(:Time, false)).to be(false)
  end

  it "serializes with defaults" do
    expect(described_class.new(**attrs).as_json).to eq(
      "type" => "time", "at" => "2025-12-04T14:00:00Z", "zone" => "America/Los_Angeles",
      "format" => "short", "label" => "auto", "variant" => "body", "textTone" => "primary"
    )
  end

  it "converts Time values to UTC ISO-8601" do
    expect(described_class.new(at: Time.utc(2025, 12, 4, 14), zone: "UTC").at).to eq("2025-12-04T14:00:00Z")
  end

  it "converts zoned Time values to UTC" do
    expect(described_class.new(at: Time.new(2025, 12, 4, 6, 0, 0, "-08:00"), zone: "UTC").at)
      .to eq("2025-12-04T14:00:00Z")
  end

  described_class::FORMAT.each do |format|
    it "accepts format #{format}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(**attrs, format: format))).to eq([])
    end
  end

  described_class::LABEL.each do |label|
    it "accepts label #{label}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(**attrs, label: label))).to eq([])
    end
  end

  it "rejects unknown tokens" do
    expect(UiSpecHelpers.error_pairs(described_class.new(**attrs, format: "full", label: "maybe", variant: "x")))
      .to contain_exactly(%i[format inclusion], %i[label inclusion], %i[variant inclusion])
  end

  it "applies the text tone rule (A2)" do
    expect(UiSpecHelpers.error_pairs(described_class.new(**attrs, text_tone: "danger")))
      .to eq([%i[text_tone inclusion]])
  end

  ["2025-12-04", "2025-12-04T14:00:00", "2025-12-04T14:00:00+01:00", "2025-13-04T14:00:00Z", "soon"].each do |value|
    it "rejects at #{value.inspect}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(at: value, zone: "UTC"))).to eq([%i[at invalid]])
    end
  end

  ["user", :user].each do |zone|
    it "accepts zone #{zone.inspect} and serializes it as user" do
      expect(UiSpecHelpers.error_pairs(described_class.new(at: attrs[:at], zone:))).to eq([])
      expect(described_class.new(at: attrs[:at], zone:).as_json["zone"]).to eq("user")
    end
  end

  it "requires a known zone" do
    expect(UiSpecHelpers.error_pairs(described_class.new(at: attrs[:at], zone: "Mars/Olympus")))
      .to eq([%i[zone invalid]])
    expect(UiSpecHelpers.error_pairs(described_class.new(at: attrs[:at]))).to eq([%i[zone blank]])
  end
end
