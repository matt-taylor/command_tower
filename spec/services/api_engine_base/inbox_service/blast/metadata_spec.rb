# frozen_string_literal: true

RSpec.describe ApiEngineBase::InboxService::Blast::Metadata do
  describe ".call" do
    subject(:call) { described_class.() }

    it "succeeds" do
      expect(call.success?).to be(true)
    end

    it "sets metadata_blast" do
      expect(call.metadata).to be_a(ApiEngineBase::Schema::Inbox::MessageBlastMetadata)
      expect(call.metadata.count).to eq(0)
    end

    context "with message_blasts" do
      before { create_list(:message_blast, 5) }

      it "succeeds" do
        expect(call.success?).to be(true)
      end

      it "sets metadata_blast" do
        expect(call.metadata).to be_a(ApiEngineBase::Schema::Inbox::MessageBlastMetadata)
        expect(call.metadata.entities).to all(be_a(ApiEngineBase::Schema::Inbox::MessageBlastEntity))
        expect(call.metadata.count).to eq(5)
      end
    end
  end
end
