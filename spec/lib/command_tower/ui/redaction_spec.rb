# frozen_string_literal: true

RSpec.describe CommandTower::UI::Redaction, :aggregate_failures do
  let(:secret) { "SECRET-4821-XYZ" }
  let(:code) { CommandTower::UI::Nodes::Code.new(value: secret, format: "text", label: "Check-in code") }
  let(:root) { UiSpecHelpers.stack(UiSpecHelpers.text("Hi"), UiSpecHelpers.stack(code)) }
  let(:document) { UiSpecHelpers.document(root) }

  describe ".call" do
    subject(:redacted) { described_class.call(document, impersonating: true) }

    it "never contains the value through as_json, inspect or to_s" do
      expect(JSON.generate(redacted.as_json)).not_to include(secret)
      expect(redacted.inspect).not_to include(secret)
      expect(redacted.to_s).not_to include(secret)
      expect(redacted.root.inspect).not_to include(secret)
    end

    it "replaces the code with a secondary body text node" do
      expect(redacted.as_json.dig("root", "children", 1, "children", 0)).to include(
        "type" => "text", "variant" => "body", "textTone" => "secondary",
        "spans" => [{ "type" => "text", "text" => "Open the app to check in" }]
      )
    end

    it "drops the label" do
      expect(JSON.generate(redacted.as_json)).not_to include("Check-in code")
    end

    it "produces a valid document" do
      expect { redacted.validate! }.not_to raise_error
    end

    it "does not mutate the input document" do
      redacted

      expect(document.as_json.dig("root", "children", 1, "children", 0, "value")).to eq(secret)
    end

    context "with a component fallback" do
      let(:component) { CommandTower::UI::Nodes::Component.new(key: "demo.card", fallback: code) }

      it "redacts a code inside it" do
        expect(JSON.generate(described_class.call(UiSpecHelpers.document(component), impersonating: true).as_json))
          .not_to include(secret)
      end
    end

    it "redacts when the impersonation state is unknown" do
      expect(JSON.generate(described_class.call(document, impersonating: nil).as_json)).not_to include(secret)
    end

    it "returns the same document when explicitly not impersonating" do
      expect(described_class.call(document, impersonating: false)).to equal(document)
    end
  end
end
