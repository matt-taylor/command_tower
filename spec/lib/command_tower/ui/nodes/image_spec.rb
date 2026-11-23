# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Image, :aggregate_failures do
  let(:hosts) { UiSpecHelpers.wire_hardening["images"]["hosts"] }
  let(:attrs) { { src: "https://img.example.com/a.png", alt: "A cat", aspect: 1.5 } }

  before { allow(CommandTower.config.ui).to receive(:image_hosts).and_return(hosts) }

  it "serializes with defaults" do
    expect(described_class.new(**attrs).as_json).to eq(
      "type" => "image", "src" => "https://img.example.com/a.png", "alt" => "A cat", "decorative" => false,
      "aspect" => 1.5, "animated" => false, "fit" => "cover"
    )
  end

  UiSpecHelpers.wire_hardening["images"]["valid"].each do |src|
    it "accepts #{src.inspect}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(**attrs, src: src))).to eq([])
    end
  end

  UiSpecHelpers.wire_hardening["images"]["invalid"].each do |src|
    it "rejects #{src.inspect}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(**attrs, src: src)).map(&:first)).to eq(%i[src])
    end
  end

  context "with no configured hosts" do
    let(:hosts) { [] }

    it "fails closed" do
      expect(UiSpecHelpers.error_pairs(described_class.new(**attrs))).to eq([%i[src host_not_allowed]])
    end
  end

  it "requires alt unless decorative (A12)" do
    expect(UiSpecHelpers.error_pairs(described_class.new(**attrs, alt: ""))).to eq([%i[alt blank]])
    expect(UiSpecHelpers.error_pairs(described_class.new(**attrs, alt: nil))).to eq([%i[alt blank]])
  end

  it "allows an empty alt when explicitly decorative" do
    expect(UiSpecHelpers.error_pairs(described_class.new(**attrs, alt: "", decorative: true))).to eq([])
  end

  it "requires a positive aspect" do
    expect(UiSpecHelpers.error_pairs(described_class.new(**attrs, aspect: nil))).to eq([%i[aspect not_a_number]])
    expect(UiSpecHelpers.error_pairs(described_class.new(**attrs, aspect: 0)))
      .to eq([%i[aspect greater_than_or_equal_to]])
  end

  it "validates fit" do
    expect(UiSpecHelpers.error_pairs(described_class.new(**attrs, fit: "stretch"))).to eq([%i[fit inclusion]])
  end
end
