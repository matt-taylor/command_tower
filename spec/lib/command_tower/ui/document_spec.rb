# frozen_string_literal: true

RSpec.describe CommandTower::UI::Document, :aggregate_failures do
  describe "envelope" do
    subject(:document) { UiSpecHelpers.document(UiSpecHelpers.text("Hi"), text_fallback: "Hi") }

    it "serializes schema, catalog, root and textFallback" do # rubocop:disable RSpec/ExampleLength
      expect(document.as_json).to eq(
        "schema" => "ui_document",
        "catalog" => CommandTower::UI::CATALOG,
        "root" => document.root.as_json,
        "textFallback" => "Hi"
      )
    end

    it "validates and returns itself" do
      expect(document.validate!).to equal(document)
    end

    it "does not print the tree in inspect or to_s" do
      expect(document.inspect).not_to include("Hi")
      expect(document.to_s).not_to include("Hi")
    end
  end

  describe "#validate!" do
    it "raises for an unknown profile" do
      expect { UiSpecHelpers.document(UiSpecHelpers.text).validate!(profile: :blocking_notice) }
        .to raise_error(ArgumentError)
    end

    it "accepts the default profile explicitly" do
      expect { UiSpecHelpers.document(UiSpecHelpers.text).validate!(profile: :default) }.not_to raise_error
    end

    context "with a blank textFallback" do
      it "reports it" do
        expect { UiSpecHelpers.document(UiSpecHelpers.text, text_fallback: "").validate! }
          .to raise_error(CommandTower::UI::InvalidDocumentError) { |error|
            expect(error.details).to eq([{ path: "textFallback", code: "blank" }])
          }
      end
    end

    context "with an oversized textFallback" do
      let(:document) { UiSpecHelpers.document(UiSpecHelpers.text, text_fallback: "z" * 8_001) }

      it "reports it without echoing it" do
        expect(document.validation_errors).to eq([{ path: "textFallback", code: "too_long" }])
      end
    end

    context "when root is not a node" do
      it "reports invalid_node" do
        expect(UiSpecHelpers.document("nope").validation_errors).to include({ path: "root", code: "invalid_node" })
      end
    end

    context "with invalid tokens deep in the tree" do
      subject(:details) do
        root = UiSpecHelpers.stack(
          UiSpecHelpers.stack(CommandTower::UI::Nodes::Badge.new(label: "SECRET-LABEL", tone: "loud"))
        )
        UiSpecHelpers.document(root).validation_errors
      end

      it "gives the node path and code only" do
        expect(details).to eq([{ path: "root.children[0].children[0].tone", code: "inclusion" }])
      end
    end

    context "with secret-looking values" do
      let(:secret_root) do
        UiSpecHelpers.stack(CommandTower::UI::Nodes::Badge.new(label: "SECRET-LABEL", tone: "SECRET-TONE"))
      end

      it "keeps values out of the exception message and details" do # rubocop:disable RSpec/ExampleLength
        expect { UiSpecHelpers.document(secret_root).validate! }
          .to raise_error(CommandTower::UI::InvalidDocumentError) { |error|
            expect(error.message).not_to include("SECRET")
            expect(error.details.to_s).not_to include("SECRET")
            expect(error.message).to include("root.children[0].tone:inclusion")
          }
      end
    end

    context "with many errors" do
      let(:many_errors_root) do
        UiSpecHelpers.stack(*Array.new(15) { CommandTower::UI::Nodes::Badge.new(label: "x", tone: "bad") })
      end

      it "caps how many errors the message lists" do
        expect { UiSpecHelpers.document(many_errors_root).validate! }
          .to raise_error(CommandTower::UI::InvalidDocumentError) { |error|
            expect(error.details.length).to eq(15)
            expect(error.message).to include("(+5 more)")
          }
      end
    end
  end

  describe "limits (shared fixture cases)" do
    UiSpecHelpers.wire_hardening["limits"]["cases"].each do |limit_case|
      context limit_case["name"] do
        subject(:details) { UiSpecHelpers.document(UiSpecHelpers.limit_root(limit_case["build"])).validation_errors }

        if limit_case["valid"]
          it "is valid" do
            expect(details).to eq([])
          end
        else
          it "reports #{limit_case['error']['code']} at #{limit_case['error']['path']}" do
            expect(details).to include({ path: limit_case["error"]["path"], code: limit_case["error"]["code"] })
          end
        end
      end
    end
  end

  describe "singleton rules across nesting" do
    let(:inner_component) { CommandTower::UI::Nodes::Component.new(key: "a.inner", fallback: UiSpecHelpers.text) }
    let(:outer_component) { CommandTower::UI::Nodes::Component.new(key: "a.outer", fallback: inner_component) }
    let(:buttons) do
      [
        CommandTower::UI::Nodes::Button.new(label: "Go", variant: "primary", action: UiSpecHelpers.navigate),
        CommandTower::UI::Nodes::Button.new(label: "Later", variant: "secondary", action: UiSpecHelpers.navigate)
      ]
    end

    it "counts a component inside another component's fallback" do
      expect(UiSpecHelpers.document(outer_component).validation_errors)
        .to include({ path: "root.fallback", code: "multiple_components" })
    end

    it "allows primary plus secondary buttons" do
      expect(UiSpecHelpers.document(UiSpecHelpers.stack(*buttons)).validation_errors).to eq([])
    end
  end
end
