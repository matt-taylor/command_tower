# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Rendering::InboxPresentationSnapshot, :messaging_notification_types do
  let(:recipient_id) { 4242 }
  let(:doubles) { "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles" }

  describe ".capture" do
    context "when the document has no presentation node" do
      before do
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: "rich_messaging_plain",
            inbox_document_composer: "#{doubles}::ValidTypeComposer",
          ),
        )
      end

      let(:communication) do
        build(:messaging_communication, notification_type_key: "rich_messaging_plain", body: "Narrative", metadata: nil)
      end

      subject(:snapshot) { described_class.capture(communication:, recipient_id:) }

      it "returns nil" do
        expect(snapshot).to be_nil
      end
    end

    context "when the presentation composer succeeds" do
      before do
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: "rich_messaging_with_presentation",
            inbox_document_composer: "#{doubles}::TypeComposerWithPresentation",
          ),
        )
        CommandTower.config.registry.inbox_presentations.presentation("rich_messaging_proof.make_picks") do |presentation|
          presentation.composer_class = "#{doubles}::PresentationComposerDouble"
          presentation.output_keys = [:example]
        end
        allow(CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::PresentationComposerDouble)
          .to receive(:call).and_call_original
      end

      let(:communication) do
        build(:messaging_communication, notification_type_key: "rich_messaging_with_presentation", body: "Unused", metadata: nil)
      end

      subject(:snapshot) { described_class.capture(communication:, recipient_id:) }

      it "returns the projected snapshot for that recipient" do
        expect(snapshot).to eq(
          "v" => 1,
          "key" => "rich_messaging_proof.make_picks",
          "variant" => "compact",
          "data" => { "example" => "data" },
        )
        expect(CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::PresentationComposerDouble)
          .to have_received(:call).with(communication:, recipient_id:)
      end
    end

    context "when the presentation key is unregistered" do
      before do
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: "rich_messaging_with_presentation",
            inbox_document_composer: "#{doubles}::TypeComposerWithPresentation",
          ),
        )
      end

      let(:communication) do
        build(:messaging_communication, notification_type_key: "rich_messaging_with_presentation", body: "Unused", metadata: nil)
      end

      subject(:snapshot) { described_class.capture(communication:, recipient_id:) }

      it "returns the omitted marker instead of nil" do
        expect(snapshot).to eq("v" => 1, "omitted" => true)
      end
    end

    context "when the presentation composer raises" do
      before do
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: "rich_messaging_with_presentation",
            inbox_document_composer: "#{doubles}::TypeComposerWithPresentation",
          ),
        )
        CommandTower.config.registry.inbox_presentations.presentation("rich_messaging_proof.make_picks") do |presentation|
          presentation.composer_class = "#{doubles}::RaisingPresentationComposerDouble"
          presentation.output_keys = [:example]
        end
      end

      let(:communication) do
        build(:messaging_communication, notification_type_key: "rich_messaging_with_presentation", body: "Unused", metadata: nil)
      end

      subject(:snapshot) { described_class.capture(communication:, recipient_id:) }

      it "returns the omitted marker instead of nil" do
        expect(snapshot).to eq("v" => 1, "omitted" => true)
      end
    end

    context "when the presentation composer fails" do
      before do
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: "rich_messaging_with_presentation",
            inbox_document_composer: "#{doubles}::TypeComposerWithPresentation",
          ),
        )
        CommandTower.config.registry.inbox_presentations.presentation("rich_messaging_proof.make_picks") do |presentation|
          presentation.composer_class = "#{doubles}::FailingApplicationServiceStylePresentationComposerDouble"
          presentation.output_keys = [:example]
        end
      end

      let(:communication) do
        build(:messaging_communication, notification_type_key: "rich_messaging_with_presentation", body: "Unused", metadata: nil)
      end

      subject(:snapshot) { described_class.capture(communication:, recipient_id:) }

      it "returns the omitted marker instead of nil" do
        expect(snapshot).to eq("v" => 1, "omitted" => true)
      end
    end

    context "when the document has two presentation nodes" do
      before do
        register_and_seal_notification_types(
          build_notification_type_declaration(
            key: "rich_messaging_two_registered",
            inbox_document_composer: "#{doubles}::TypeComposerWithTwoRegisteredPresentations",
          ),
        )
        CommandTower.config.registry.inbox_presentations.presentation("rich_messaging_proof.make_picks") do |presentation|
          presentation.composer_class = "#{doubles}::PresentationComposerDouble"
          presentation.output_keys = [:example]
        end
        CommandTower.config.registry.inbox_presentations.presentation("rich_messaging_proof.second") do |presentation|
          presentation.composer_class = "#{doubles}::SecondPresentationComposerDouble"
          presentation.output_keys = [:example]
        end
        allow(CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::SecondPresentationComposerDouble)
          .to receive(:call)
      end

      let(:communication) do
        build(:messaging_communication, notification_type_key: "rich_messaging_two_registered", body: "Unused", metadata: nil)
      end

      subject(:snapshot) { described_class.capture(communication:, recipient_id:) }

      it "captures only the first presentation" do
        expect(snapshot).to eq(
          "v" => 1,
          "key" => "rich_messaging_proof.make_picks",
          "variant" => "compact",
          "data" => { "example" => "data" },
        )
        expect(CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::SecondPresentationComposerDouble)
          .not_to have_received(:call)
      end
    end
  end
end
