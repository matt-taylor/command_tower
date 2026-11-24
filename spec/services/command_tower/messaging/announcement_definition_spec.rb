# frozen_string_literal: true

require "command_tower/rspec/message_definition"

RSpec.describe CommandTower::Messaging::AnnouncementDefinition, :messaging_accept do
  let(:definition) { described_class }
  let(:metadata) { definition.fixtures.fetch("default") }
  let(:context) do
    CommandTower::Messaging::Definitions::RenderContext.new(
      notification_type_key: "promotional_announcement", metadata:, metadata_version: 1, slots: nil,
      render_zone: "America/New_York"
    )
  end
  let(:slots) { CommandTower::Messaging::Definitions::DocumentBuilder.slots(definition: definition.new, context:) }

  it "is promotional, versioned, and skips the fact block", :aggregate_failures do
    expect(definition).to be_promotional
    expect(definition.metadata_version).to eq(1)
    expect(definition.document_profile).to eq(:default)
    expect(definition.required_facts).to be_empty
  end

  it "defaults its zone to the platform UI zone" do
    expect(definition.default_zone).to eq(CommandTower.config.ui.default_zone)
  end

  it "keeps :message as the profile of other definitions" do
    expect(CommandTower::Messaging::MessageDefinition.document_profile).to eq(:message)
  end

  describe "metadata schema" do
    it "requires a title and a body" do
      expect(definition.metadata_schema.schema_errors({})).to contain_exactly("title", "body_markdown")
    end

    it "limits the title to 200 and the body to 5000 characters" do
      expect(definition.metadata_schema.schema_errors("title" => "t" * 201, "body_markdown" => "b" * 5001))
        .to contain_exactly("title", "body_markdown")
    end

    it "accepts the limits" do
      expect(definition.metadata_schema.schema_errors("title" => "t" * 200, "body_markdown" => "b" * 5000)).to be_empty
    end
  end

  describe "documents" do
    %i[inbox email].each do |channel|
      describe "#{channel} document" do
        let(:wire) do
          CommandTower::Messaging::Definitions::DocumentBuilder
            .public_send(channel, definition: definition.new, context:).as_json
        end

        it "builds without a facts node", :aggregate_failures do
          expect(CommandTower::Testing::MessageDefinitionRendering.node_types(wire["root"])).not_to include("facts")
          expect(wire.to_s).to include("New classes this week", "three")
        end
      end
    end

    describe "email rendering" do
      let(:communication) do
        CommandTower::Messaging::Communication.new(
          id: 1, notification_type_key: "promotional_announcement", title: "New classes this week", body: "x",
          metadata:, metadata_version: 1, slots: slots.transform_keys(&:to_s), render_zone: "America/New_York"
        )
      end

      before do
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: "promotional_announcement", allowed_channels: %w[email], default_channels: %w[email],
            message: described_class.name,
            default_preference_state: { "channels" => { "email" => true }, "inbox" => true }
          )
        )
        allow(Rails.logger).to receive(:warn)
      end

      it "renders through the composer without falling back", :aggregate_failures do
        expect(CommandTower::Messaging::Rendering::DefinedEmailRenderer.render(communication:, definition:).html)
          .to include("New classes this week")
        expect(Rails.logger).not_to have_received(:warn).with(/email_document_fallback/)
      end
    end
  end

  describe "slots" do
    it "uses the title for headline and subject", :aggregate_failures do
      expect(slots[:headline]).to eq("New classes this week")
      expect(slots[:subject]).to eq("New classes this week")
    end

    it "derives push and Pushover text from the markdown on one line", :aggregate_failures do
      expect(slots[:push_body]).to include("We added three classes.")
      expect(slots[:push_body]).not_to include("**")
      expect(slots[:push_body]).not_to include("\n")
      expect(slots[:pushover_message]).to eq(slots[:push_body])
    end

    it "writes the SMS body as app name and title" do
      expect(slots[:sms_body]).to eq("#{CommandTower.app_name_for_comms}: New classes this week")
    end

    context "with a long body" do
      let(:metadata) { { "title" => "Long", "body_markdown" => "word " * 400 } }

      it "truncates push text at 178 characters" do
        expect(slots[:push_body].length).to eq(178)
      end
    end
  end
end
