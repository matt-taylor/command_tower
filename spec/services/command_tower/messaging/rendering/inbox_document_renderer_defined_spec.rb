# frozen_string_literal: true

# InboxDocumentRenderer with the catalog and impersonation inputs: undefined types render the same
# for every catalog (regression), defined types go through the MessageDefinition composer.
RSpec.describe CommandTower::Messaging::Rendering::InboxDocumentRenderer,
               :defined_render, :messaging_notification_types do
  let(:communication) do
    build(
      :messaging_communication,
      id: 77, notification_type_key: "defined.render", body: "Check in is open",
      metadata: { "headline" => "Check in is open", "class_name" => "Arms", "door_code" => secret_code },
      metadata_version: 1, slots: { "headline" => "Check in is open" }, render_zone: "America/Los_Angeles"
    )
  end

  describe "undefined type regression" do
    let(:undefined) do
      build(
        :messaging_communication,
        notification_type_key: "rich_messaging_unregistered",
        body: "Plain body",
        metadata: { "deep_link_path" => "/schedule", "cta_label" => "See schedule" }
      )
    end

    it "renders the same content for catalog 1 and catalog 2" do
      expect(render(ui_catalog: 2, communication: undefined).to_h)
        .to eq(render(ui_catalog: 1, communication: undefined).to_h)
    end

    it "renders inbox_document_v1 for catalog 2" do
      expect(render(ui_catalog: 2, communication: undefined).to_h).to include(schema: "inbox_document_v1")
    end

    it "renders the same content when impersonating" do
      expect(render(impersonating: true, communication: undefined).to_h).to eq(render(communication: undefined).to_h)
    end

    it "keeps the generic paragraph and cta blocks" do
      expect(render(communication: undefined).blocks.pluck(:type)).to eq(%w[paragraph cta])
    end
  end

  describe "defined type" do
    before do
      register_definition(
        definition_class do
          define_method(:facts) do |builder, metadata:|
            builder.facts do |f|
              f.key_value { |rows| rows.item "Class", metadata["class_name"] }
              f.code value: metadata["door_code"], label: "Door code", format: :text
            end
          end
        end
      )
    end

    context "with catalog 2" do
      it "returns a ui_document at catalog 2" do
        expect(render(ui_catalog: 2).as_json).to include("schema" => "ui_document", "catalog" => 2)
      end

      it "carries the code value when not impersonating" do
        expect(render(ui_catalog: 2).as_json.to_json).to include(secret_code)
      end

      it "omits the code value when impersonating" do
        expect(render(ui_catalog: 2, impersonating: true).as_json.to_json).not_to include(secret_code)
      end

      it "omits the code value when impersonation is unknown" do
        expect(render(ui_catalog: 2, impersonating: nil).as_json.to_json).not_to include(secret_code)
      end

      it "replaces the code with the redaction text when impersonating" do
        expect(render(ui_catalog: 2, impersonating: true).as_json.to_json)
          .to include(CommandTower::UI::Redaction::REPLACEMENT_TEXT)
      end
    end

    context "with catalog 1" do
      it "returns inbox_document_v1 blocks from the legacy mapping" do
        expect(render(ui_catalog: 1).to_h).to include(schema: "inbox_document_v1")
      end

      it "never carries the code value" do
        expect(render(ui_catalog: 1).to_h.to_json).not_to include(secret_code)
      end

      it "maps the headline to a paragraph" do
        expect(render(ui_catalog: 1).blocks).to include({ type: "paragraph", text: "Check in is open" })
      end
    end
  end

  describe "message profile validation" do
    before do
      register_definition(
        definition_class do
          define_method(:inbox) do |builder, **|
            builder.text("No fact block")
          end
        end
      )
    end

    it "rejects a document without a fact block outside production" do
      expect { render(ui_catalog: 2) }.to raise_error(CommandTower::UI::InvalidDocumentError)
    end
  end

  describe "composer failure" do
    let(:failing_definition) do
      definition_class do
        define_method(:facts) do |builder, metadata:|
          builder.facts { |f| f.key_value { |rows| rows.item "Class", metadata["class_name"] } }
        end

        define_method(:inbox) do |_builder, **|
          raise "boom #{SecretMarker}"
        end
      end
    end

    before do
      stub_const("SecretMarker", secret_code)
      register_definition(failing_definition)
    end

    context "when not in production" do
      it "raises so the definition bug is visible" do
        expect { render(ui_catalog: 2) }.to raise_error(RuntimeError, /boom/)
      end
    end

    context "when in production" do
      before do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Rails.logger).to receive(:warn)
      end

      it "falls back to the :basic document" do
        expect(render(ui_catalog: 2).as_json.to_json).to include("Check in is open")
      end

      it "logs inbox_document_fallback with ids only" do
        render(ui_catalog: 2)
        expect(Rails.logger).to have_received(:warn).with(
          a_string_including("inbox_document_fallback", "communication_id=77", "notification_type_key=defined.render")
        )
      end

      it "keeps metadata values and error messages out of the log" do
        render(ui_catalog: 2)
        expect(Rails.logger).not_to have_received(:warn).with(a_string_including(secret_code))
      end

      it "still redacts the code when impersonating" do
        expect(render(ui_catalog: 2, impersonating: true).as_json.to_json).not_to include(secret_code)
      end
    end
  end
end
