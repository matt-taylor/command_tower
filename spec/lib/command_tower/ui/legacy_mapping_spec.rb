# frozen_string_literal: true

RSpec.describe CommandTower::UI::LegacyMapping, :aggregate_failures do
  let(:at) { Time.utc(2025, 12, 4, 14) }
  let(:keys) { [] }
  let(:blocks) { UiSpecHelpers.legacy_blocks(keys:, &build) }

  describe ".call" do
    let(:document) { CommandTower::UI.document(text_fallback: "x") { |d| d.stack { |s| s.text "Hi" } } }
    let(:result) { described_class.call(document) }

    it "returns a real InboxDocument built by the Builder" do
      expect(result).to be_a(CommandTower::Messaging::Rendering::InboxDocument)
      expect(result.schema).to eq("inbox_document_v1")
      expect(result.blocks).to be_frozen
    end
  end

  context "with text spans" do
    let(:build) do
      proc { |d| d.stack { |s| s.text("Class ", s.strong("canceled"), s.link("go", action: s.navigate(path: "/c"))) } }
    end

    it "maps to a paragraph with spans flattened" do
      expect(blocks).to eq([{ type: "paragraph", text: "Class canceledgo" }])
    end
  end

  context "with a time" do
    let(:build) { proc { |d| d.stack { |s| s.time(at:, zone: "America/New_York") } } }

    it "maps to an instant" do
      expect(blocks).to eq([{ type: "instant", at: "2025-12-04T14:00:00Z" }])
    end
  end

  context "with an internal button" do
    let(:build) { proc { |d| d.stack { |s| s.button "Open", action: s.navigate(path: "/inbox") } } }

    it "maps to a cta with an internal destination" do
      expect(blocks).to eq([{ type: "cta", label: "Open", destination: { kind: "internal", path: "/inbox" } }])
    end
  end

  context "with allowed external buttons" do
    let(:hrefs) { ["https://example.com/a", "mailto:a@example.com", "tel:+15551234567"] }
    let(:build) { proc { |d| d.stack { |s| hrefs.each { |href| s.button "Go", action: s.navigate(href:) } } } }

    it "maps https, mailto and tel to external destinations" do
      expect(blocks.pluck(:destination)).to eq(hrefs.map { |href| { kind: "external", href: } })
    end
  end

  context "with destinations the Builder would accept but the allowlist rejects" do
    let(:hrefs) { ["ftp://example.com/a", "http://example.com/a", "https://user:pw@example.com/a"] }
    let(:build) { proc { |d| d.stack { |s| hrefs.each { |href| s.button "Go", action: s.navigate(href:) } } } }

    it "drops the buttons" do
      expect(blocks).to eq([])
    end
  end

  context "with an unsafe internal path" do
    let(:build) { proc { |d| d.stack { |s| s.button "Bad", action: s.navigate(path: "//evil.example") } } }

    it "drops the button" do
      expect(blocks).to eq([])
    end
  end

  context "with a component" do
    let(:build) do
      proc { |d| d.component(key: "pickem.make_picks", variant: "compact", data: { a: 1 }) { |c| c.text "Fallback" } }
    end

    it "maps a listed key to a presentation block without data" do
      keys << "pickem.make_picks"
      expect(blocks).to eq([{ type: "presentation", key: "pickem.make_picks", variant: "compact" }])
    end

    it "maps an unlisted key through its fallback tree" do
      expect(blocks).to eq([{ type: "paragraph", text: "Fallback" }])
    end
  end

  context "with facts" do
    let(:build) do
      proc do |d|
        d.stack do |s|
          s.facts do |f|
            f.key_value { |kv| kv.item "When", kv.time(at:, zone: "UTC") }
            f.badge "Paid"
          end
        end
      end
    end

    it "maps the children in order" do
      expect(blocks.pluck(:text)).to eq(["When: Thu, Dec 4, 2:00 PM UTC", "Paid"])
    end
  end

  context "with banner, stat tile, divider, avatar and image" do
    let(:build) do
      proc do |d|
        d.stack do |s|
          s.banner "Body", title: "Heads up"
          s.stat_tile value: "3", label: "Spots"
          s.divider
          s.avatar initials: "AB", alt: "Ann"
          s.image src: "https://example.com/a.png", aspect: 1.0, alt: "A photo"
        end
      end
    end

    it "derives text for the text-bearing nodes and drops the rest" do
      expect(blocks.pluck(:text)).to eq(["Heads up\nBody", "Spots: 3", "A photo"])
    end
  end

  context "with a code" do
    let(:build) do
      proc do |d|
        d.stack do |s|
          s.text "Your code"
          s.code value: "987654", label: "Door", format: :text
        end
      end
    end

    it "drops it and never emits its value" do
      expect(blocks).to eq([{ type: "paragraph", text: "Your code" }])
      expect(blocks.to_s).not_to include("987654")
    end
  end
end
