# frozen_string_literal: true

RSpec.describe ApiEngineBase::InboxService::Blast::Retrieve do
  let(:message_blast) { create(:message_blast) }

  describe ".call" do
    subject(:call) { described_class.(id:) }

    let(:id) { message_blast.id }

    it "succeeds" do
      expect(call.success?).to be(true)
    end

    it "returns message_blast" do
      expect(call.message_blast).to be_a(ApiEngineBase::Schema::Inbox::MessageBlastEntity)
    end

    it "returns correct content" do
      expect(call.message_blast.title).to eq(message_blast.title)
      expect(call.message_blast.text).to eq(message_blast.text)
    end

    context "with incorrect id" do
      let(:id) { 1 }

      it "fails" do
        expect(call.failure?).to be(true)
      end

      it "does not set message_blast" do
        expect(call.message_blast).to be(nil)
      end
    end
  end
end
