# frozen_string_literal: true

RSpec.describe ApiEngineBase::InboxService::Message::Metadata do
  let(:user) { create(:user) }

  describe ".call" do
    subject(:call) { described_class.(user:) }

    it "succeeds" do
      expect(call.success?).to eq(true)
    end

    it "sets empty metadata" do
      expect(call.metadata).to be_a(ApiEngineBase::Schema::Inbox::Metadata)
      expect(call.metadata.count).to eq(0)
      expect(call.metadata.entities).to eq([])
    end

    context "with messages" do
      before { create_list(:message, count, user:) }
      let(:count) { 1 }

      it "succeeds" do
        expect(call.success?).to eq(true)
      end

      it "sets metadata" do
        expect(call.metadata).to be_a(ApiEngineBase::Schema::Inbox::Metadata)
        expect(call.metadata.count).to eq(count)
      end

      context "with many" do
        let(:count) { 10 }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "sets metadata" do
          expect(call.metadata).to be_a(ApiEngineBase::Schema::Inbox::Metadata)
          expect(call.metadata.count).to eq(count)
        end
      end
    end
  end
end
