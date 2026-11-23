# frozen_string_literal: true

RSpec.describe CommandTower::UI::Nodes::Code, :aggregate_failures do
  let(:secret) { "SECRET-CHECKIN-7731" }
  let(:node) { described_class.new(value: secret, format: "qr", label: "Check-in code") }
  let(:bad_node) { described_class.new(value: secret, format: "barcode", label: "Check-in code") }
  let(:too_long_node) { described_class.new(value: "#{secret}#{'x' * 2_001}", format: "text", label: "Code") }
  let(:document) { UiSpecHelpers.document(UiSpecHelpers.stack(node)) }

  it "serializes on the wire, the one place the value is emitted for the client" do
    expect(node.as_json).to eq("type" => "code", "value" => secret, "format" => "qr", "label" => "Check-in code")
  end

  CommandTower::UI::Nodes::Code::FORMAT.each do |format|
    it "accepts format #{format}" do
      expect(UiSpecHelpers.error_pairs(described_class.new(value: "1", format: format, label: "x"))).to eq([])
    end
  end

  it "requires value, label and a known format" do
    expect(UiSpecHelpers.error_pairs(described_class.new(format: "barcode")))
      .to contain_exactly(%i[value blank], %i[label blank], %i[format inclusion])
  end

  describe "redaction" do
    it "keeps the value out of inspect, to_s and pretty print" do
      expect(node.inspect).not_to include(secret)
      expect(node.to_s).not_to include(secret)
      expect(PP.pp(node, +"")).not_to include(secret)
      expect(node.inspect).to include("REDACTED")
    end

    it "keeps the value out of a parent's inspect" do
      expect(UiSpecHelpers.stack(node).inspect).not_to include(secret)
      expect(PP.pp(UiSpecHelpers.stack(node), +"")).not_to include(secret)
    end

    it "keeps the value out of validation errors" do
      bad_node.valid?
      expect(bad_node.errors.inspect).not_to include(secret)
      expect(bad_node.errors.full_messages.join).not_to include(secret)
      expect(bad_node.errors.details.to_s).not_to include(secret)
      expect(bad_node.errors.to_hash.to_s).not_to include(secret)
    end

    it "keeps the value out of the length error" do
      too_long_node.valid?
      expect(too_long_node.errors.inspect).not_to include(secret)
      expect(too_long_node.errors.full_messages.join).not_to include(secret)
    end

    it "keeps the value out of document validation errors, as exception, details and JSON" do # rubocop:disable RSpec/ExampleLength
      expect { UiSpecHelpers.document(UiSpecHelpers.stack(bad_node)).validate! }
        .to raise_error(CommandTower::UI::InvalidDocumentError) { |error|
          expect(error.message).not_to include(secret)
          expect(error.details.to_json).not_to include(secret)
          expect(error.details).to eq([{ path: "root.children[0].format", code: "inclusion" }])
          expect(error.inspect).not_to include(secret)
        }
    end

    it "keeps the value out of the Document itself" do
      expect(document.inspect).not_to include(secret)
      expect(document.to_s).not_to include(secret)
    end
  end
end
