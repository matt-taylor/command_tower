# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Definitions::DocumentBuilder, :message_definition_document_builder do
  let(:fact_fragment) do
    Class.new(CommandTower::UI::Fragments::Facts) do
      def compose(builder, metadata:)
        builder.key_value { |rows| rows.item "Class", metadata["class_name"] }
      end
    end
  end

  let(:definition) do
    fragment = fact_fragment
    Class.new(CommandTower::Messaging::MessageDefinition) do
      define_method(:facts) { |builder, metadata:| fragment.call(builder, metadata:) }

      def slots(metadata:, **tools)
        when_text = tools[:t].call(metadata["starts_at"], zone: metadata["studio_zone"], format: :short)
        {
          headline: "Class canceled",
          subject: "Canceled #{metadata['class_name']}, #{when_text}",
          sms_body: nil
        }
      end
    end.new
  end

  let(:metadata) do
    { "class_name" => "Arms", "headline" => "Arms is canceled", "starts_at" => "2026-12-04T14:00:00Z",
      "studio_zone" => "America/Los_Angeles", "deep_link_path" => "/schedule" }
  end

  describe ".inbox with the :basic layout" do
    it "is a raised card of headline, fact block, primary button", :aggregate_failures do
      expect(inbox_root).to include("type" => "card", "surface" => "raised")
      expect(child_types(inbox_root)).to eq(%w[text facts button])
      expect(inbox_root["children"].values_at(0, 2).pluck("variant")).to eq(%w[heading_m primary])
    end

    context "with a known app name" do
      before { allow(CommandTower).to receive(:app_name).and_return("Studio") }

      it "labels the button 'Open in {app_name}' by default" do
        expect(inbox_root["children"][2]["label"]).to eq("Open in Studio")
      end
    end

    it "uses cta_label when present" do
      expect(inbox_root_for(metadata: metadata.merge("cta_label" => "See schedule"))["children"][2]["label"])
        .to eq("See schedule")
    end

    it "uses the metadata headline when no slots are stored" do
      expect(inbox_root["children"][0]["spans"].to_s).to include("Arms is canceled")
    end

    it "prefers the stored headline slot" do
      expect(inbox_root_for(slots: { "headline" => "From slots" })["children"][0]["spans"].to_s)
        .to include("From slots")
    end

    it "accepts an external https deep link" do
      expect(inbox_root_for(metadata: metadata.except("deep_link_path").merge("deep_link" => "https://example.com/x"))["children"][2]["action"]["destination"])
        .to eq("kind" => "external", "href" => "https://example.com/x")
    end

    it "has no button without a deep link (G2)" do
      expect(child_types(inbox_root_for(metadata: metadata.except("deep_link_path")))).to eq(%w[text facts])
    end

    it "has no button for an unsafe deep link" do
      expect(
        child_types(
          inbox_root_for(metadata: metadata.except("deep_link_path").merge("deep_link" => "javascript:alert(1)"))
        )
      ).to eq(%w[text facts])
    end

    it "derives a text fallback" do
      expect(described_class.inbox(definition:, context: context_for).text_fallback).to include("Arms")
    end
  end

  describe ".email" do
    it "builds the basic layout for email" do
      expect(child_types(described_class.email(definition:, context: context_for).as_json["root"]))
        .to include("facts")
    end
  end

  describe "composer overrides" do
    let(:overriding) do
      Class.new(definition.class) do
        def inbox(builder, metadata:)
          builder.card(surface: :raised) do |card|
            card.facts
            card.text(metadata["class_name"])
          end
        end
      end
    end

    it "inserts the fact block with a blockless d.facts" do
      expect(child_types(inbox_root(definition: overriding.new))).to eq(%w[facts text])
    end
  end

  describe "validation" do
    let(:bare_definition) { Class.new(CommandTower::Messaging::MessageDefinition) }

    it "raises with paths and codes when the fact block is missing" do
      expect { described_class.inbox(definition: bare_definition.new, context: context_for) }
        .to raise_error(an_instance_of(CommandTower::UI::InvalidDocumentError)
          .and(having_attributes(details: include(a_hash_including(code: "missing_facts_node")))))
    end

    it "skips the fact check for another profile" do
      expect(described_class.inbox(definition: bare_definition.new, context: context_for, profile: :default))
        .to be_a(CommandTower::UI::Document)
    end

    context "when the composer adds no root" do
      let(:empty) { Class.new(bare_definition) { def inbox(_builder, **) = nil } }

      it "raises" do
        expect { described_class.inbox(definition: empty.new, context: context_for) }
          .to raise_error(CommandTower::UI::InvalidDocumentError, /root_required/)
      end
    end

    context "when facts calls d.facts" do
      let(:looping) { Class.new(bare_definition) { def facts(builder, **) = builder.facts } }

      it "does not recurse" do
        expect { described_class.inbox(definition: looping.new, context: context_for) }.to raise_error(ArgumentError)
      end
    end
  end

  describe ".facts" do
    it "returns the fact block as a document" do
      expect(described_class.facts(definition:, context: context_for).as_json["root"]["type"]).to eq("facts")
    end

    it "returns nil when the definition has no fact block" do
      expect(described_class.facts(definition: CommandTower::Messaging::MessageDefinition.new, context: context_for))
        .to be_nil
    end
  end

  describe ".slots" do
    let(:user_zoned) do
      Class.new(CommandTower::Messaging::MessageDefinition) do
        def slots(metadata:, **tools)
          { headline: tools[:t].call(metadata["starts_at"], zone: :user, format: :time) }
        end
      end
    end

    it "returns symbol-keyed slots without nils", :aggregate_failures do
      expect(described_class.slots(definition:, context: context_for).keys).to eq(%i[headline subject])
      expect(described_class.slots(definition:, context: context_for)[:subject])
        .to eq("Canceled Arms, Fri, Dec 4, 6:00 AM PT")
    end

    it "resolves zone: :user to render_zone" do
      expect(described_class.slots(definition: user_zoned.new, context: context_for)[:headline])
        .to eq("9:00 AM ET")
    end

    it "defaults to the headline slot from metadata" do
      expect(described_class.slots(definition: CommandTower::Messaging::MessageDefinition.new, context: context_for))
        .to eq(headline: "Arms is canceled")
    end
  end
end
