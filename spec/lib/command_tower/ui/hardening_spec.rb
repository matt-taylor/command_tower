# frozen_string_literal: true

RSpec.describe CommandTower::UI::Hardening, :aggregate_failures do
  let(:fixture) { UiSpecHelpers.wire_hardening }

  describe ".internal_path?" do
    UiSpecHelpers.wire_hardening["internalPaths"]["valid"].each do |path|
      it "accepts #{path.inspect}" do
        expect(described_class.internal_path?(path)).to be(true)
      end
    end

    UiSpecHelpers.wire_hardening["internalPaths"]["invalid"].each do |path|
      it "rejects #{path.inspect}" do
        expect(described_class.internal_path?(path)).to be(false)
      end
    end

    it "rejects non-strings" do
      expect(described_class.internal_path?(nil)).to be(false)
    end
  end

  describe ".external_href_code" do
    UiSpecHelpers.wire_hardening["externalHrefs"]["valid"].each do |href|
      it "accepts #{href.inspect}" do
        expect(described_class.external_href_code(href)).to be_nil
      end
    end

    UiSpecHelpers.wire_hardening["externalHrefs"]["invalid"].each do |href|
      it "rejects #{href.inspect}" do
        expect(described_class.external_href_code(href)).not_to be_nil
      end
    end

    it "names the failure class" do
      expect(described_class.external_href_code("https://good.com@evil.com")).to eq(:userinfo)
      expect(described_class.external_href_code("javascript:alert(1)")).to eq(:unsafe_scheme)
      expect(described_class.external_href_code("mailto:nope")).to eq(:invalid_href)
    end
  end

  describe ".image_src_code" do
    let(:hosts) { fixture["images"]["hosts"] }

    UiSpecHelpers.wire_hardening["images"]["valid"].each do |src|
      it "accepts #{src.inspect}" do
        expect(described_class.image_src_code(src, hosts: hosts)).to be_nil
      end
    end

    UiSpecHelpers.wire_hardening["images"]["invalid"].each do |src|
      it "rejects #{src.inspect}" do
        expect(described_class.image_src_code(src, hosts: hosts)).not_to be_nil
      end
    end

    it "fails closed with no hosts" do
      expect(described_class.image_src_code("https://img.example.com/a.png", hosts: [])).to eq(:host_not_allowed)
    end
  end

  describe "limits parity with the shared fixture" do
    it "matches the Ruby constants" do # rubocop:disable RSpec/ExampleLength
      expect(fixture["limits"]).to include(
        "maxNodes" => CommandTower::UI::Limits::MAX_NODES,
        "maxDepth" => CommandTower::UI::Limits::MAX_DEPTH,
        "maxBytes" => CommandTower::UI::Limits::MAX_BYTES,
        "maxStringLength" => CommandTower::UI::Limits::MAX_STRING_LENGTH,
        "maxTextFallbackLength" => CommandTower::UI::Limits::MAX_TEXT_FALLBACK_LENGTH,
        "maxSpans" => CommandTower::UI::Limits::MAX_SPANS,
        "maxKeyValueItems" => CommandTower::UI::Limits::MAX_KEY_VALUE_ITEMS,
        "maxFactsNodes" => CommandTower::UI::Limits::MAX_FACTS_NODES
      )
    end
  end
end
