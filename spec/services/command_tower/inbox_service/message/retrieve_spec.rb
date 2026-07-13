# frozen_string_literal: true

RSpec.describe CommandTower::InboxService::Message::Retrieve do
  let(:user) { create(:user) }
  let!(:message) { create(:message, user:) }
  let(:id) { message.id }

  describe ".call" do
    subject(:call) { described_class.(user:, id:) }

    it "succeeds" do
      expect(call.success?).to be(true)
    end

    it "sets message" do
      expect(call.message).to be_a(CommandTower::Schema::Entities::Inbox::MessageEntity)

      expect(call.message.title).to eq(message.title)
      expect(call.message.id).to eq(message.id)
      expect(call.message.text).to eq(message.text)
      expect(call.message.viewed).to eq(true)
      expect(call.message.created_at).to be_present
      expect(call.message.created_at).to be_a(String)
      expect(call.message.created_at).to eq(message.created_at.iso8601)
      # Verify it's a valid ISO 8601 date string
      expect { Time.iso8601(call.message.created_at) }.not_to raise_error
    end

    it "changes viewed" do
      expect { call }.to change { message.reload.viewed }.from(false).to(true)
    end

    context "with incorrect id" do
      let(:id) { 12345678 }

      it "fails" do
        expect(call.failure?).to be(true)
      end

      it "does not set message" do
        expect(call.message).to be_nil
      end
    end
  end
end
