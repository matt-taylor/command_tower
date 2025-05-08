# frozen_string_literal: true

RSpec.describe CommandTower::InboxService::Message::Metadata do
  let(:user) { create(:user) }

  describe ".call" do
    subject(:call) { described_class.(user:, pagination:) }

    let(:pagination) { nil }

    it "succeeds" do
      expect(call.success?).to eq(true)
    end

    it "sets empty metadata" do
      expect(call.metadata).to be_a(CommandTower::Schema::Inbox::Metadata)
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
        expect(call.metadata).to be_a(CommandTower::Schema::Inbox::Metadata)
        expect(call.metadata.count).to eq(count)
      end

      context "with many" do
        let(:count) { 10 }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "sets metadata" do
          expect(call.metadata).to be_a(CommandTower::Schema::Inbox::Metadata)
          expect(call.metadata.count).to eq(count)
        end
      end
    end

    context "with include_examples" do
      let!(:records) { create_list(:message, count, user:) }
      let(:records_chain) { [:metadata, :entities] }
      let(:records_count) { [:metadata, :count] }

      include_examples "Services Pagination examples", ::Message
    end
  end
end
