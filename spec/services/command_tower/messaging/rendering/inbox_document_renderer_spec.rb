# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Rendering::InboxDocumentRenderer do
  let(:recipient_id) { 4242 }

  describe ".render" do
    context "generic fallback (no notification type is registered at all)" do
      context "with a body-only communication and no metadata" do
        let(:communication) do
          build(:messaging_communication, notification_type_key: "rich_messaging_unregistered", body: "Body only", metadata: nil)
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "builds one paragraph block from body" do
          expect(document.blocks).to eq([{ type: "paragraph", text: "Body only" }])
        end
      end

      context "when metadata has a safe https deep_link and no cta_label" do
        let(:communication) do
          build(
            :messaging_communication,
            notification_type_key: "rich_messaging_unregistered",
            body: "Body",
            metadata: { "deep_link" => "https://example.com/x" },
          )
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "adds a cta block with the default label and an external destination" do
          expect(document.blocks).to include(
            { type: "cta", label: "Open", destination: { kind: "external", href: "https://example.com/x" } }
          )
        end
      end

      context "when metadata has a safe custom-scheme deep_link and a cta_label" do
        let(:communication) do
          build(
            :messaging_communication,
            notification_type_key: "rich_messaging_unregistered",
            body: "Body",
            metadata: { "deep_link" => "pickem://announcements/1", "cta_label" => "Complete picks" },
          )
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "adds a cta block with the custom label and an external destination" do
          expect(document.blocks).to include(
            { type: "cta", label: "Complete picks", destination: { kind: "external", href: "pickem://announcements/1" } }
          )
        end
      end

      context "when metadata has a safe deep_link_path and a cta_label" do
        let(:communication) do
          build(
            :messaging_communication,
            notification_type_key: "rich_messaging_unregistered",
            body: "Body",
            metadata: {
              "deep_link_path" => "/no-dues-test/picks?competitionPeriodId=1297",
              "deep_link" => "https://frontend.example/no-dues-test/picks?competitionPeriodId=1297",
              "cta_label" => "Finish my picks",
            },
          )
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "prefers the internal destination over the external deep_link" do
          expect(document.blocks).to include(
            {
              type: "cta",
              label: "Finish my picks",
              destination: { kind: "internal", path: "/no-dues-test/picks?competitionPeriodId=1297" },
            }
          )
        end
      end

      context "when metadata deep_link_path is protocol-relative" do
        let(:communication) do
          build(
            :messaging_communication,
            notification_type_key: "rich_messaging_unregistered",
            body: "Body",
            metadata: { "deep_link_path" => "//evil.example/phish", "cta_label" => "Open" },
          )
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "omits the cta block" do
          expect(document.blocks.map { |block| block[:type] }).not_to include("cta")
        end
      end

      context "when metadata deep_link uses an unsafe scheme" do
        let(:communication) do
          build(
            :messaging_communication,
            notification_type_key: "rich_messaging_unregistered",
            body: "Body",
            metadata: { "deep_link" => "javascript:alert(1)" },
          )
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "omits the cta block" do
          expect(document.blocks.map { |block| block[:type] }).not_to include("cta")
        end
      end

      context "when metadata deep_link is schemeless" do
        let(:communication) do
          build(:messaging_communication, notification_type_key: "rich_messaging_unregistered", body: "Body", metadata: { "deep_link" => "/relative/path" })
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "omits the cta block" do
          expect(document.blocks.map { |block| block[:type] }).not_to include("cta")
        end
      end

      context "when body is blank and there is no valid cta" do
        let(:communication) do
          build(:messaging_communication, notification_type_key: "rich_messaging_unregistered", body: "", metadata: nil)
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "returns an empty blocks array" do
          expect(document.blocks).to eq([])
        end
      end
    end

    context "type-specific Ruby composer resolution", :messaging_notification_types do
      context "when a registered composer returns a valid InboxDocument" do
        before do
          register_and_seal_notification_types(
            build_notification_type_declaration(
              key: "rich_messaging_type_composer",
              inbox_document_composer: "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::ValidTypeComposer",
            ),
          )
        end

        let(:communication) do
          build(:messaging_communication, notification_type_key: "rich_messaging_type_composer", body: "Unused generic body", metadata: nil)
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "replaces the generic document entirely" do
          expect(document.blocks).to eq([{ type: "paragraph", text: "Composed narrative" }])
        end
      end

      context "when the registered declaration has no inbox_document_composer" do
        before { register_and_seal_notification_types(build_notification_type_declaration(key: "rich_messaging_no_composer")) }

        let(:communication) do
          build(:messaging_communication, notification_type_key: "rich_messaging_no_composer", body: "Fallback body", metadata: nil)
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "falls back to the generic document" do
          expect(document.blocks).to eq([{ type: "paragraph", text: "Fallback body" }])
        end
      end

      context "when the notification type is not registered at all" do
        let(:communication) do
          build(:messaging_communication, notification_type_key: "rich_messaging_never_registered", body: "Fallback body", metadata: nil)
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "falls back to the generic document without raising" do
          expect(document.blocks).to eq([{ type: "paragraph", text: "Fallback body" }])
        end
      end

      context "when inbox_document_composer names a class that does not resolve" do
        before do
          register_and_seal_notification_types(
            build_notification_type_declaration(
              key: "rich_messaging_bad_class",
              inbox_document_composer: "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::NotARealComposer",
            ),
          )
        end

        let(:communication) do
          build(:messaging_communication, notification_type_key: "rich_messaging_bad_class", body: "Fallback body", metadata: nil)
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "falls back to the generic document without raising" do
          expect(document.blocks).to eq([{ type: "paragraph", text: "Fallback body" }])
        end
      end

      context "when the composer raises mid-composition" do
        before do
          register_and_seal_notification_types(
            build_notification_type_declaration(
              key: "rich_messaging_raising_composer",
              inbox_document_composer: "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::RaisingTypeComposer",
            ),
          )
        end

        let(:communication) do
          build(:messaging_communication, notification_type_key: "rich_messaging_raising_composer", body: "Fallback on error", metadata: nil)
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "falls back to the generic document without raising" do
          expect(document.blocks).to eq([{ type: "paragraph", text: "Fallback on error" }])
        end
      end

      context "when the composer returns something other than an InboxDocument" do
        before do
          register_and_seal_notification_types(
            build_notification_type_declaration(
              key: "rich_messaging_invalid_return",
              inbox_document_composer: "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::InvalidReturnTypeComposer",
            ),
          )
        end

        let(:communication) do
          build(:messaging_communication, notification_type_key: "rich_messaging_invalid_return", body: "Fallback on invalid return", metadata: nil)
        end

        subject(:document) { described_class.render(communication:, recipient_id:) }

        it "falls back to the generic document without raising" do
          expect(document.blocks).to eq([{ type: "paragraph", text: "Fallback on invalid return" }])
        end
      end
    end

    context "presentation node resolution", :messaging_notification_types do
      before do
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: "rich_messaging_with_presentation",
            inbox_document_composer: "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::TypeComposerWithPresentation",
          ),
        )
      end

      let(:communication) do
        build(:messaging_communication, notification_type_key: "rich_messaging_with_presentation", body: "Unused", metadata: nil)
      end

      subject(:document) { described_class.render(communication:, recipient_id:) }

      context "when the presentation key is registered" do
        before do
          CommandTower.config.registry.inbox_presentations.presentation("rich_messaging_proof.make_picks") do |presentation|
            presentation.composer_class = "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::PresentationComposerDouble"
            presentation.output_keys = [:example]
          end
          allow(CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::PresentationComposerDouble)
            .to receive(:call).and_call_original
          document
        end

        it "attaches the registered composer's data to the presentation block" do
          expect(document.blocks).to include(
            { type: "presentation", key: "rich_messaging_proof.make_picks", variant: "compact", data: { example: "data" } },
          )
        end

        it "passes communication and recipient_id to the composer" do
          expect(CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::PresentationComposerDouble)
            .to have_received(:call).with(communication:, recipient_id:)
        end
      end

      context "when the presentation key is unregistered" do
        it "omits the presentation block" do
          expect(document.blocks.map { |block| block[:type] }).not_to include("presentation")
        end
      end

      context "when the registered composer fails" do
        before do
          CommandTower.config.registry.inbox_presentations.presentation("rich_messaging_proof.make_picks") do |presentation|
            presentation.composer_class = "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::RaisingPresentationComposerDouble"
            presentation.output_keys = [:example]
          end
        end

        it "omits the presentation block without raising" do
          expect(document.blocks.map { |block| block[:type] }).not_to include("presentation")
        end
      end

      context "when the registered composer is ApplicationService-shaped and succeeds" do
        before do
          CommandTower.config.registry.inbox_presentations.presentation("rich_messaging_proof.make_picks") do |presentation|
            presentation.composer_class =
              "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::" \
              "SucceedingApplicationServiceStylePresentationComposerDouble"
            presentation.output_keys = [:example]
          end
        end

        it "unwraps the ServiceResult's data into the presentation block" do
          expect(document.blocks).to include(
            { type: "presentation", key: "rich_messaging_proof.make_picks", variant: "compact", data: { example: "service_result_data" } },
          )
        end
      end

      context "when the registered composer is ApplicationService-shaped and fails" do
        before do
          CommandTower.config.registry.inbox_presentations.presentation("rich_messaging_proof.make_picks") do |presentation|
            presentation.composer_class =
              "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::" \
              "FailingApplicationServiceStylePresentationComposerDouble"
            presentation.output_keys = [:example]
          end
        end

        it "omits the presentation block without raising" do
          expect(document.blocks.map { |block| block[:type] }).not_to include("presentation")
        end
      end

      context "when the registered composer is a real ApplicationService with validated inputs" do
        before do
          CommandTower.config.registry.inbox_presentations.presentation("rich_messaging_proof.make_picks") do |presentation|
            presentation.composer_class =
              "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::" \
              "RealApplicationServicePresentationComposerDouble"
            presentation.output_keys = [:example]
          end
        end

        it "excludes the composer's declared inputs from the presentation data" do
          expect(document.blocks).to include(
            { type: "presentation", key: "rich_messaging_proof.make_picks", variant: "compact", data: { example: "real_output" } },
          )
        end
      end

      context "when the registered composer returns extra keys beyond its declared output" do
        before do
          CommandTower.config.registry.inbox_presentations.presentation("rich_messaging_proof.make_picks") do |presentation|
            presentation.composer_class =
              "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::" \
              "ExtraKeysPresentationComposerDouble"
            presentation.output_keys = [:example]
          end
        end

        it "excludes the undeclared extra key from the presentation data" do
          expect(document.blocks).to include(
            { type: "presentation", key: "rich_messaging_proof.make_picks", variant: "compact", data: { example: "data" } },
          )
        end
      end
    end

    context "one-attempt presentation cap", :messaging_notification_types do
      before do
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: "rich_messaging_two_presentations",
            inbox_document_composer: "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::TypeComposerWithTwoPresentations",
          ),
        )
        CommandTower.config.registry.inbox_presentations.presentation("rich_messaging_proof.make_picks") do |presentation|
          presentation.composer_class = "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::PresentationComposerDouble"
          presentation.output_keys = [:example]
        end
        allow(CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::PresentationComposerDouble).to receive(:call)
      end

      let(:communication) do
        build(:messaging_communication, notification_type_key: "rich_messaging_two_presentations", body: "Unused", metadata: nil)
      end

      subject(:document) { described_class.render(communication:, recipient_id:) }

      before { document }

      it "drops both presentation blocks (the first is unregistered, the second's budget is already consumed)" do
        expect(document.blocks.map { |block| block[:type] }).not_to include("presentation")
      end

      it "never invokes the second, validly-registered composer" do
        expect(CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::PresentationComposerDouble)
          .not_to have_received(:call)
      end
    end
  end
end
