# frozen_string_literal: true

# Accept for MessageDefinition-backed types: slots, stored title/body, render zone, fingerprint.
RSpec.describe CommandTower::Messaging::Accept::Coordinator, :defined_type_accept, :messaging_accept do
  let(:user) { create(:user) }
  let(:metadata) { { "headline" => "Class canceled", "class_name" => "Arms" } }
  let(:metadata_schema) do
    Class.new(CommandTower::Messaging::MessageDefinition::Metadata) do
      attribute :headline, :string
      attribute :class_name, :string
      validates :class_name, presence: true
    end
  end

  before do
    stub_const("DefinedSample", build_definition(version: 1, schema: metadata_schema))
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: "defined.sample", allowed_channels: %w[email], default_channels: %w[email], message: "DefinedSample"
      )
    )
  end

  describe "stored fields" do
    it "stores slots with string keys and drops nil slots" do
      expect(stored(accept).slots).to eq("headline" => "Class canceled", "subject" => "Subject")
    end

    it "sets title to the headline" do
      expect(stored(accept).title).to eq("Class canceled")
    end

    it "sets body to the headline when there is no push_body" do
      expect(stored(accept).body).to eq("Class canceled")
    end

    it "sets body to push_body when present" do
      expect(stored(accept(metadata: metadata.merge("push" => "Short push"))).body).to eq("Short push")
    end

    it "stores the metadata version" do
      expect(stored(accept).metadata_version).to eq(1)
    end

    it "is definition-backed" do
      expect(stored(accept)).to be_message_definition_backed
    end
  end

  describe "render_zone" do
    context "with a valid last_known_timezone" do
      before { set_zone(user, "America/New_York") }

      it "uses the recipient zone" do
        expect(stored(accept).render_zone).to eq("America/New_York")
      end
    end

    context "with an invalid last_known_timezone" do
      before { set_zone(user, "Not/AZone") }

      it "falls back to the definition default_zone" do
        expect(stored(accept).render_zone).to eq("America/Los_Angeles")
      end
    end

    it "falls back to the definition default_zone when the recipient has no zone" do
      expect(stored(accept).render_zone).to eq("America/Los_Angeles")
    end

    context "with two recipients in different zones" do
      let(:other_user) { create(:user) }

      before do
        set_zone(user, "America/New_York")
        set_zone(other_user, "Europe/Paris")
      end

      it "resolves per recipient" do
        expect([accept, accept(recipient_id: other_user.id)].map { |result| stored(result).render_zone })
          .to eq(%w[America/New_York Europe/Paris])
      end
    end
  end

  describe "idempotency" do
    let!(:first_result) { accept }

    it "replays an identical request" do
      expect(accept).to have_attributes(idempotent_replay: true, communication_id: first_result.communication_id)
    end

    it "rejects supplied title and body rather than replaying (D17)" do
      expect { accept(title: "Other", body: "Other body") }.to raise_error(validation_error, /must not be supplied/)
    end

    context "when the definition's metadata_version changed" do
      before { stub_const("DefinedSample", build_definition(version: 2, schema: metadata_schema)) }

      it "raises IdempotencyConflictError" do
        expect { accept }.to raise_error(CommandTower::Messaging::Accept::IdempotencyConflictError)
      end
    end
  end

  describe "fingerprint basis" do
    let(:canonical_keys) do
      JSON.parse(
        CommandTower::Messaging::Accept::RequestNormalizer.new(
          title: "t", body: "b", metadata:, preference_state: nil, platform_enabled_channels: [],
          message_overrides: nil, metadata_version: 1
        ).canonical_json
      ).keys
    end

    it "excludes title and body and includes metadata_version" do
      expect(canonical_keys).to eq(
        %w[metadata preference_state platform_enabled_channels message_overrides metadata_version]
      )
    end
  end

  describe "metadata schema violation" do
    let(:metadata) { { "headline" => "Secret headline" } }

    context "when strict_definitions is true" do
      before { allow(CommandTower.config.messaging).to receive(:strict_definitions).and_return(true) }

      it "fails with attribute names only" do
        expect { accept }.to raise_error(validation_error, /metadata_schema_violation \(attributes: class_name\)/)
      end

      it "never puts metadata values in the error" do
        expect { accept }.to raise_error(validation_error, satisfy { |message| message.exclude?("Secret") })
      end

      it "persists nothing" do
        rejected_accept

        expect(CommandTower::Messaging::Communication.count).to eq(0)
      end
    end

    context "when strict_definitions is false" do
      before do
        allow(CommandTower.config.messaging).to receive(:strict_definitions).and_return(false)
        allow(publisher).to receive(:warn).and_call_original
      end

      it "degrades and stores the definition title" do
        expect(stored(accept).title).to eq("Secret headline")
      end

      it "logs metadata_schema_violation with attribute names only" do
        accept

        expect(publisher).to have_received(:warn).with(
          hash_including(event: "messaging.accept.metadata_schema_violation", attributes: ["class_name"])
        )
      end
    end
  end

  describe "unusable slots when strict_definitions is false" do
    before { allow(CommandTower.config.messaging).to receive(:strict_definitions).and_return(false) }

    context "when the slots cannot be built" do
      before do
        stub_const("DefinedSample", Class.new(DefinedSample) do
          def slots(metadata:, **) = raise("boom #{metadata['headline']}")
        end)
      end

      it "still fails" do
        expect { accept }.to raise_error(validation_error, /slots_unbuildable/)
      end
    end

    context "when the headline is blank" do
      let(:metadata) { { "headline" => " ", "class_name" => "Arms" } }

      it "still fails" do
        expect { accept }.to raise_error(validation_error, /headline_missing/)
      end
    end
  end
end
