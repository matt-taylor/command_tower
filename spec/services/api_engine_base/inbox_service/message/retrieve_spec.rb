# frozen_string_literal: true

RSpec.describe ApiEngineBase::InboxService::Message::Retrieve do
  let(:user) { create(:user) }
  let!(:message) { create(:message, user:) }
  let(:id) { message.id }

  describe ".call" do
    subject(:call) { described_class.(user:, id:) }

    it "succeeds" do
      expect(call.success?).to be(true)
    end

    it "sets message" do
      expect(call.message).to be_a(ApiEngineBase::Schema::Inbox::MessageEntity)

      expect(call.message.title).to eq(message.title)
      expect(call.message.id).to eq(message.id)
      expect(call.message.text).to eq(message.text)
      expect(call.message.viewed).to eq(true)
    end

    it "changes viewed" do
      expect { call }.to change { message.reload.viewed }.from(false).to(true)
    end

    context "with incorrect id" do
      let(:id) { 100 }

      it "fails" do
        expect(call.failure?).to be(true)
      end

      it "does not set message" do
        expect(call.message).to be_nil
      end
    end
  end
end
