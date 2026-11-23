# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Action::Navigate, :aggregate_failures do # rubocop:disable RSpec/SpecFilePathFormat
  it "serializes an internal destination" do
    expect(described_class.new(path: "/inbox").as_json).to eq(
      "type" => "navigate", "destination" => { "kind" => "internal", "path" => "/inbox" }
    )
  end

  it "serializes an external destination" do
    expect(described_class.new(href: "https://example.com").as_json).to eq(
      "type" => "navigate", "destination" => { "kind" => "external", "href" => "https://example.com" }
    )
  end

  it "needs a destination" do
    expect(UiSpecHelpers.error_pairs(described_class.new)).to eq([%i[base destination_required]])
  end

  it "rejects both destinations at once" do
    expect(UiSpecHelpers.error_pairs(described_class.new(path: "/a", href: "https://example.com")))
      .to eq([%i[base ambiguous_destination]])
  end

  UiSpecHelpers.wire_hardening["internalPaths"]["valid"].each do |path|
    it "accepts internal path #{path.inspect}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(path: path))).to eq([])
    end
  end

  UiSpecHelpers.wire_hardening["internalPaths"]["invalid"].each do |path|
    it "rejects internal path #{path.inspect}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(path: path))).to eq([%i[path invalid_path]])
    end
  end

  UiSpecHelpers.wire_hardening["externalHrefs"]["valid"].each do |href|
    it "accepts href #{href.inspect}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(href: href))).to eq([])
    end
  end

  UiSpecHelpers.wire_hardening["externalHrefs"]["invalid"].each do |href|
    it "rejects href #{href.inspect}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(href: href)).map(&:first)).to eq(%i[href])
    end
  end
end
