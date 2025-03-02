# frozen_string_literal: true

RSpec.describe CommandTower::InboxService::Message::Send do

  describe ".call" do
    subject(:call) { described_class.(**params) }
    let(:params) do
      {
        user:,
        text:,
        title:,
        message_blast:,
        pushed: false, # Not implemented yet
      }
    end
    let(:user) { create(:user) }
    let(:text) { Faker::Lorem.paragraph(sentence_count: (3...15).to_a.sample) }
    let(:title) { Faker::Lorem.sentence(word_count: 3) }
    let(:message_blast) { nil }

    it "succeeds" do
      expect(call.success?).to be(true)
    end

    it "sends message" do
      expect { call }.to change { user.reload.messages.count }.by(1)
    end

    it "message has correct params" do
      call
      message = user.messages.last

      expect(message.text).to eq(text)
      expect(message.title).to eq(title)
      expect(message.message_blast).to eq(nil)
    end

    context "with message_blast" do
      let(:message_blast) { create(:message_blast) }

      it "succeeds" do
        expect(call.success?).to be(true)
      end

      it "sends message" do
        expect { call }.to change { user.reload.messages.count }.by(1)
      end

      it "message has correct params" do
        call
        message = user.messages.last

        expect(message.text).to eq(text)
        expect(message.title).to eq(title)
        expect(message.message_blast).to eq(message_blast)
      end
    end
  end
end
