# frozen_string_literal: true

require "tmpdir"

RSpec.describe CommandTower::UI::ZoneAbbreviation do
  let(:winter) { Time.utc(2026, 1, 15, 12) }
  let(:summer) { Time.utc(2026, 7, 15, 12) }

  it "has tzdata in the image" do
    expect(File.exist?("/usr/share/zoneinfo/tzdata.zi")).to be(true)
  end

  describe ".generate" do
    subject(:generated) { described_class.generate(year: 2026) }

    let(:labels) { generated.fetch("zoneAbbreviations") }

    it "reads the tzdata version" do
      expect(generated.fetch("tzdataVersion")).to match(/\A\d{4}[a-z]\z/)
    end

    {
      "America/Los_Angeles" => "PT", "America/New_York" => "ET", "America/Chicago" => "CT",
      "America/Denver" => "MT", "America/Anchorage" => "AKT",
      "America/Phoenix" => "MST", "Pacific/Honolulu" => "HST", "UTC" => "UTC"
    }.each do |zone, expected|
      it "maps #{zone} to #{expected} (rule 1 collapses DST pairs, rule 2 keeps unambiguous abbreviations)" do
        expect(labels.fetch(zone)).to eq(expected)
      end
    end

    %w[Asia/Kolkata Europe/Dublin Europe/London Europe/Paris].each do |zone|
      it "leaves #{zone} out of the map (rule 3)" do
        expect(labels).not_to have_key(zone)
      end
    end

    it "lists ambiguous abbreviations" do
      expect(generated.fetch("ambiguousAbbreviations")).to include("IST", "CST")
    end

    it "sorts zones" do
      expect(labels.keys).to eq(labels.keys.sort)
    end

    it "sorts ambiguous abbreviations" do
      expect(generated.fetch("ambiguousAbbreviations")).to eq(generated.fetch("ambiguousAbbreviations").sort)
    end

    it "is deterministic" do
      expect(described_class.generate(year: 2026)).to eq(generated)
    end
  end

  describe ".label" do
    let(:mapping) { described_class.generate(year: 2026).fetch("zoneAbbreviations") }

    {
      ["America/Los_Angeles", :summer] => "PT", ["America/New_York", :winter] => "ET",
      ["America/Anchorage", :summer] => "AKT", ["America/Phoenix", :summer] => "MST",
      ["Pacific/Honolulu", :summer] => "HST", ["UTC", :winter] => "UTC",
      ["Asia/Kolkata", :winter] => "GMT+5:30", ["Europe/Dublin", :winter] => "GMT",
      ["Europe/Dublin", :summer] => "GMT+1", ["Europe/London", :winter] => "GMT",
      ["Europe/London", :summer] => "GMT+1", ["Europe/Paris", :winter] => "GMT+1",
      ["Europe/Paris", :summer] => "GMT+2"
    }.each do |(zone, season), expected|
      it "labels #{zone} in #{season} as #{expected}" do
        expect(described_class.label(zone, public_send(season), mapping: mapping)).to eq(expected)
      end
    end

    it "uses the committed mapping by default" do
      expect(described_class.label("America/Los_Angeles", summer)).to eq("PT")
    end
  end

  describe ".write!" do
    let(:dir) { Dir.mktmpdir }
    let(:path) { File.join(dir, "mapping.json") }
    let(:head) { %({\n  "fixtureVersion": 1,\n  "spacing": { "none": 0 },\n  "zoneAbbreviations": {) }

    before { File.write(path, %({\n  "fixtureVersion": 1,\n  "spacing": { "none": 0 }\n}\n)) }

    after { FileUtils.remove_entry(dir) }

    it "splices the generated keys after the existing content" do
      described_class.write!(year: 2026, path: path)

      expect(File.read(path)).to start_with(head)
    end

    it "writes only the three generated keys after the existing ones" do
      described_class.write!(year: 2026, path: path)

      expect(JSON.parse(File.read(path)).keys).to eq(%w[fixtureVersion spacing] + described_class::GENERATED_KEYS)
    end

    it "is byte-identical on re-run" do
      described_class.write!(year: 2026, path: path)

      expect { described_class.write!(year: 2026, path: path) }.not_to(change { File.read(path) })
    end
  end
end
