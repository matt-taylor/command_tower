# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::NotificationTypes::MessageDefinitionChecks,
               :message_definition_seal, :messaging_notification_types do
  let(:base) { CommandTower::Messaging::MessageDefinition }
  let(:invalid_error) { CommandTower::Messaging::NotificationTypes::InvalidDeclarationError }
  let(:registry) { CommandTower::Messaging::NotificationTypes::Registry.instance }

  # A valid definition for allowed_channels %w[email sms].
  let(:definition) do
    Class.new(base) do
      metadata_version 1
      default_zone "America/Los_Angeles"
      fixture :default, metadata: { "headline" => "Hello" }

      def slots(metadata:, **)
        { headline: metadata["headline"], subject: "Subject", sms_body: "Body" }
      end
    end
  end

  before { stub_const("SealCheckSample", definition) }

  describe "Declaration.build(message:)" do
    it "stores the class name without constantizing it" do
      expect(build_notification_type_declaration(message: "NotYetLoaded::Definition").message)
        .to eq("NotYetLoaded::Definition")
    end

    it "accepts a class and stores its name" do
      expect(build_notification_type_declaration(message: definition).message).to eq(definition.to_s)
    end

    it "defaults message to nil" do
      expect(build_notification_type_declaration.message).to be_nil
    end

    it "registers before the class exists" do
      expect { registry.register(build_notification_type_declaration(message: "Missing::Klass")) }
        .not_to raise_error
    end

    it "fails at seal when the class never appears" do
      registry.register(build_notification_type_declaration(message: "Missing::Klass"))

      expect { registry.seal }.to raise_error(invalid_error, /Missing::Klass/)
    end
  end

  describe "seal" do
    it "accepts a valid definition" do
      expect(seal_with(declaration)).to be(true)
    end

    context "when the class is not a MessageDefinition" do
      before { stub_const("SealCheckSample", Class.new) }

      it "rejects it" do
        expect_seal_error(/MessageDefinition subclass/)
      end
    end

    it "rejects message: together with inbox_document_composer" do
      expect_seal_error(/mutually exclusive/, declaration(inbox_document_composer: "Some::Composer"))
    end

    it "rejects per-type ERB" do
      Dir.mktmpdir do |dir|
        host_root_with_type_template(dir, "example_type")

        expect_seal_error(/per-type ERB/, declaration(key: "example_type"))
      end
    end

    it "rejects an invalid default_zone" do
      definition.default_zone "Mars/Olympus"

      expect_seal_error(/default_zone/)
    end

    context "with no fixture" do
      before { stub_const("SealCheckSample", Class.new(base) { metadata_version 1 }) }

      it "rejects the definition" do
        expect_seal_error(/at least one fixture/)
      end
    end

    context "with a zero metadata_version" do
      before { stub_const("SealCheckSample", Class.new(definition) { metadata_version 0 }) }

      it "rejects the definition" do
        expect_seal_error(/metadata_version/)
      end
    end

    context "with a non-integer metadata_version" do
      before { stub_const("SealCheckSample", Class.new(definition) { metadata_version "1" }) }

      it "rejects the definition" do
        expect_seal_error(/metadata_version/)
      end
    end

    it "rejects first-fixture slots without a headline" do
      stub_slots(subject: "Subject", sms_body: "Body")

      expect_seal_error(/missing: headline/)
    end

    it "rejects first-fixture slots missing an allowed channel's slot" do
      stub_slots(headline: "Hello", subject: "Subject")

      expect_seal_error(/missing: sms_body/)
    end

    context "when slots raises" do
      before do
        stub_const("SealCheckSample", Class.new(definition) { define_method(:slots) { |**| raise "secret detail" } })
      end

      it "reports the class name only" do
        expect_seal_error(/RuntimeError\)\z/)
      end
    end
  end

  describe "seal of a promotional definition without a postal_address" do
    before do
      definition.promotional true
      allow(CommandTower.config.messaging.compliance).to receive(:postal_address).and_return(nil)
    end

    it "rejects the definition" do
      expect_seal_error(/postal_address/)
    end
  end

  describe "seal of a promotional definition with a postal_address" do
    before do
      definition.promotional true
      allow(CommandTower.config.messaging.compliance).to receive(:postal_address).and_return("1 Example St")
    end

    it "accepts the definition" do
      expect(seal_with(declaration)).to be(true)
    end
  end

  describe "inbox_document_composer deprecation" do
    before { allow(Rails.logger).to receive(:warn) }

    it "logs one line naming every composer type" do
      seal_with(
        build_notification_type_declaration(key: "legacy.one", inbox_document_composer: "A::B"),
        build_notification_type_declaration(key: "legacy.two", inbox_document_composer: "A::C")
      )

      expect(Rails.logger).to have_received(:warn).with(/deprecated.*legacy\.one, legacy\.two/).once
    end

    it "logs nothing for undefined types" do
      seal_with(build_notification_type_declaration)

      expect(Rails.logger).not_to have_received(:warn).with(/DEPRECATION/)
    end
  end
end
