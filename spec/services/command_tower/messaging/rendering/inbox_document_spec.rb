# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Rendering::InboxDocument do
  describe ".build" do
    context "with a valid blocks array" do
      subject(:document) { described_class.build(blocks: [{ type: "paragraph", text: "Hello" }]) }

      it "tags the schema as inbox_document_v1" do
        expect(document.schema).to eq("inbox_document_v1")
      end

      it "freezes the built document" do
        expect(document).to be_frozen
      end

      it "preserves the given blocks" do
        expect(document.blocks).to eq([{ type: "paragraph", text: "Hello" }])
      end
    end

    context "with an empty blocks array" do
      subject(:document) { described_class.build(blocks: []) }

      it "accepts an empty blocks array" do
        expect(document.blocks).to eq([])
      end
    end

    context "when blocks is not an Array" do
      subject(:build_call) { described_class.build(blocks: "not-an-array") }

      it "raises ArgumentError" do
        expect { build_call }.to raise_error(ArgumentError, /blocks must be an Array/)
      end
    end

    context "when blocks contains a non-Hash entry" do
      subject(:build_call) { described_class.build(blocks: ["not-a-hash"]) }

      it "raises ArgumentError" do
        expect { build_call }.to raise_error(ArgumentError, /arbitrary hashes are not accepted/)
      end
    end
  end

  describe "#to_h" do
    subject(:hash) { described_class.build(blocks: [{ type: "paragraph", text: "Hello" }]).to_h }

    it "returns a plain, directly JSON-serializable Hash" do
      expect(hash).to eq(schema: "inbox_document_v1", blocks: [{ type: "paragraph", text: "Hello" }])
    end
  end

  describe ".compose" do
    context "when authoring paragraph, cta, and presentation blocks in order" do
      subject(:document) do
        described_class.compose do |doc|
          doc.paragraph "First paragraph"
          doc.presentation "pickem.make_picks", variant: :compact
          doc.cta "Finish my picks", href: "https://example.com/picks"
        end
      end

      it "tags the schema as inbox_document_v1" do
        expect(document.schema).to eq("inbox_document_v1")
      end

      it "preserves authoring order" do
        expect(document.blocks.map { |block| block[:type] }).to eq(%w[paragraph presentation cta])
      end

      it "builds the paragraph block" do
        expect(document.blocks[0]).to eq(type: "paragraph", text: "First paragraph")
      end

      it "builds the presentation block with no data/props key at all" do
        expect(document.blocks[1]).to eq(type: "presentation", key: "pickem.make_picks", variant: "compact")
      end

      it "builds the cta block with an external destination" do
        expect(document.blocks[2]).to eq(
          type: "cta",
          label: "Finish my picks",
          destination: { kind: "external", href: "https://example.com/picks" }
        )
      end

      it "returns a frozen document" do
        expect(document).to be_frozen
      end

      it "freezes each block" do
        expect(document.blocks).to all(be_frozen)
      end
    end

    context "when presentation is authored without a variant" do
      subject(:document) { described_class.compose { |doc| doc.presentation "pickem.make_picks" } }

      it "omits variant as nil rather than a stray key" do
        expect(document.blocks).to eq([{ type: "presentation", key: "pickem.make_picks", variant: nil }])
      end
    end

    context "when paragraph text is nil or empty" do
      subject(:document) do
        described_class.compose do |doc|
          doc.paragraph nil
          doc.paragraph ""
        end
      end

      it "produces no blocks for either call" do
        expect(document.blocks).to eq([])
      end
    end

    context "when cta href is blank" do
      subject(:document) { described_class.compose { |doc| doc.cta "Label", href: "" } }

      it "produces no cta block" do
        expect(document.blocks).to eq([])
      end
    end

    context "when cta href uses an unsafe scheme" do
      subject(:document) { described_class.compose { |doc| doc.cta "Label", href: "javascript:alert(1)" } }

      it "produces no cta block" do
        expect(document.blocks).to eq([])
      end
    end

    context "when cta label is blank" do
      subject(:document) { described_class.compose { |doc| doc.cta "", href: "https://example.com" } }

      it "falls back to the default label" do
        expect(document.blocks).to eq(
          [{ type: "cta", label: "Open", destination: { kind: "external", href: "https://example.com" } }]
        )
      end
    end

    context "when cta is authored with an internal path" do
      subject(:document) do
        described_class.compose { |doc| doc.cta "Finish my picks", path: "/no-dues-test/picks?competitionPeriodId=1297" }
      end

      it "builds a cta block with an internal destination" do
        expect(document.blocks).to eq(
          [
            {
              type: "cta",
              label: "Finish my picks",
              destination: { kind: "internal", path: "/no-dues-test/picks?competitionPeriodId=1297" }
            }
          ]
        )
      end
    end

    context "when cta is authored with both path and href" do
      subject(:document) do
        described_class.compose { |doc| doc.cta "Label", path: "/internal/route", href: "https://example.com" }
      end

      it "prefers the internal destination" do
        expect(document.blocks).to eq(
          [{ type: "cta", label: "Label", destination: { kind: "internal", path: "/internal/route" } }]
        )
      end
    end

    context "when cta path is blank" do
      subject(:document) { described_class.compose { |doc| doc.cta "Label", path: "" } }

      it "produces no cta block" do
        expect(document.blocks).to eq([])
      end
    end

    context "when cta path does not start with a slash" do
      subject(:document) { described_class.compose { |doc| doc.cta "Label", path: "no-dues-test/picks" } }

      it "produces no cta block" do
        expect(document.blocks).to eq([])
      end
    end

    context "when cta path is protocol-relative" do
      subject(:document) { described_class.compose { |doc| doc.cta "Label", path: "//evil.example/phish" } }

      it "produces no cta block" do
        expect(document.blocks).to eq([])
      end
    end

    context "when no blocks are authored" do
      subject(:document) { described_class.compose { |_doc| nil } }

      it "builds an empty, valid document" do
        expect(document.blocks).to eq([])
      end
    end

    context "when authoring an instant" do
      let(:utc) { Time.utc(2026, 10, 14, 1, 0, 0) }

      context "with a Time" do
        subject(:document) { described_class.compose { |doc| doc.instant(utc) } }

        it "stores it as UTC ISO-8601" do
          expect(document.schema).to eq("inbox_document_v1")
          expect(document.blocks).to eq([{ type: "instant", at: "2026-10-14T01:00:00Z" }])
        end
      end

      context "with an offset ISO string" do
        subject(:document) { described_class.compose { |doc| doc.instant("2026-10-13T18:00:00-07:00") } }

        it "normalizes it to UTC" do
          expect(document.blocks).to eq([{ type: "instant", at: "2026-10-14T01:00:00Z" }])
        end
      end

      context "with blank, offset-less, and invalid values" do
        subject(:document) do
          described_class.compose do |doc|
            doc.paragraph "Kept"
            doc.instant(" ")
            doc.instant("2026-10-14T01:00:00")
            doc.instant("not-a-time")
            doc.instant(nil)
            doc.cta "Open", path: "/inbox"
          end
        end

        it "omits them without raising" do
          expect(document.blocks.map { |block| block[:type] }).to eq(%w[paragraph cta])
        end
      end

      context "with paragraph and cta beside a valid instant" do
        subject(:document) do
          described_class.compose do |doc|
            doc.paragraph "Before"
            doc.instant(utc)
            doc.cta "Open", path: "/inbox"
          end
        end

        it "keeps all three blocks" do
          expect(document.blocks.map { |block| block[:type] }).to eq(%w[paragraph instant cta])
        end
      end
    end
  end
end
