# frozen_string_literal: true

# Strict Produce family (D17): explicit title/body for a MessageDefinition-backed type.
RSpec.describe CommandTower::Services::Messaging::Communications::Produce, :defined_type_accept, :messaging_accept do
  let(:user) { create(:user) }
  let(:metadata) { { "headline" => "Class canceled" } }
  let(:copy) { {} }

  before do
    stub_const("DefinedSample", build_definition(version: 1, schema: CommandTower::Messaging::MessageDefinition::Metadata))
    register_and_seal_notification_types(
      build_notification_type_declaration(
        key: "defined.sample", allowed_channels: %w[email], default_channels: %w[email], message: "DefinedSample"
      )
    )
    allow(CommandTower.config.messaging).to receive(:strict_definitions).and_return(true)
    allow(publisher).to receive(:warn)
  end

  describe "Produce" do
    subject(:produced) do
      described_class.call(
        user:, notification_type_key: "defined.sample", host_event_identity: "evt/#{user.id}",
        metadata:, platform_enabled_channels: %w[email], **copy
      )
    end

    it "succeeds without title or body" do
      expect(produced).to be_success
    end

    context "with explicit copy in strict mode" do
      let(:copy) { { title: "T", body: "B" } }

      it "fails with a validation error", :aggregate_failures do
        expect(produced).not_to be_success
        expect(produced.errors.first).to be_a(CommandTower::Errors::ValidationError)
      end
    end

    context "when not strict" do
      let(:copy) { { title: "T", body: "B" } }
      let(:stored_title) { CommandTower::Messaging::Communication.find(produced.data[:communication_id]).title }

      before { allow(CommandTower.config.messaging).to receive(:strict_definitions).and_return(false) }

      it "ignores the copy, stores the derived title, and logs ids only", :aggregate_failures do
        expect(produced).to be_success
        expect(stored_title).to eq("Class canceled")
        expect(publisher).to have_received(:warn).with(hash_including(recipient_id: user.id))
      end
    end
  end

  describe "Accept coordinator" do
    it "rejects explicit copy for a defined type in every environment" do
      expect { accept(title: "T", body: "B") }.to raise_error(validation_error, /must not be supplied/)
    end
  end

  describe CommandTower::Services::Messaging::Communications::ProduceMany do
    subject(:produced_many) do
      described_class.call(
        user_ids: recipient_ids, notification_type_key: "defined.sample", campaign_identity: "camp/1",
        metadata:, platform_enabled_channels: %w[email], execution_mode: :sync, **copy
      )
    end

    let(:recipient_ids) { [user.id] }

    it "succeeds without copy" do
      expect(produced_many.data[:accepted]).to eq(1)
    end

    context "with explicit copy in strict mode" do
      let(:copy) { { title: "T", body: "B" } }

      it "fails up front, before any recipient", :aggregate_failures do
        expect(produced_many).not_to be_success
        expect(CommandTower::Messaging::Communication.count).to eq(0)
      end
    end

    context "when not strict" do
      let(:copy) { { title: "T", body: "B" } }
      let(:recipient_ids) { [user.id, create(:user).id] }

      before { allow(CommandTower.config.messaging).to receive(:strict_definitions).and_return(false) }

      it "drops the copy with a single log and accepts every recipient", :aggregate_failures do
        expect(produced_many.data[:accepted]).to eq(2)
        expect(publisher).to have_received(:warn)
          .with(hash_including(event: "messaging.produce.produce_explicit_copy_ignored")).once
      end
    end
  end

  describe CommandTower::Workflows::Messaging::Communications::ProduceRecipientWorkflow do
    subject(:workflow_result) do
      described_class.call_from_job(
        user_id: user.id, notification_type_key: "defined.sample", campaign_identity: "camp/2",
        platform_enabled_channels: %w[email], metadata:, **copy
      )
    end

    it "runs without title or body" do
      expect(workflow_result).to be_success
    end

    context "with explicit copy in strict mode" do
      let(:copy) { { title: "T", body: "B" } }

      it "fails" do
        expect(workflow_result).not_to be_success
      end
    end
  end

  describe CommandTower::Messaging::Communications::ProduceRecipientJob do
    let(:job_attrs) do
      { "notification_type_key" => "defined.sample", "campaign_identity" => "camp/3",
        "platform_enabled_channels" => %w[email], "title" => "T", "body" => "B" }
    end

    it "accepts the old title/body attrs without raising" do
      expect { described_class.new.perform(user.id, job_attrs) }.not_to raise_error
    end
  end
end
