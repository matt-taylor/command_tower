# frozen_string_literal: true

RSpec.describe ApiEngineBase::InboxService::Blast::Upsert do
  before { create_list(:user, user_count) }

  let(:user_count) { 10 }
  let(:user) { create(:user) }
  let(:params) do
    {
      user:,
      existing_users:,
      new_users:,
      text:,
      title:,
      id:,
    }.compact
  end
  let(:existing_users) { true }
  let(:new_users) { true }
  let(:text) { Faker::Lorem.paragraph(sentence_count: (3...15).to_a.sample) }
  let(:title) { Faker::Lorem.sentence(word_count: 3) }

  describe ".call" do
    subject(:call) { described_class.(**params) }

    context "with ID passed" do
      let!(:blast) { create(:message_blast) }
      let(:id) { blast.id }

      it do
        expect { call }.to_not change(MessageBlast, :count)
      end

      it "modified blast does not message existing users" do
        expect { call }.to_not change(Message, :count)
      end

      it "succeeds" do
        expect(call.success?).to be(true)
      end

      it "sets blast context" do
        expect(call.blast).to be_a(ApiEngineBase::Schema::Inbox::BlastResponse)
      end

      context "without existing_users" do
        let(:existing_users) { false }

        it do
          expect { call }.to_not change(MessageBlast, :count)
        end

        it "does not message existing_users" do
          expect { call }.to_not change(Message, :count)
        end

        it "succeeds" do
          expect(call.success?).to be(true)
        end

        it "sets blast context" do
          expect(call.blast).to be_a(ApiEngineBase::Schema::Inbox::BlastResponse)
        end
      end
    end

    context "when no id passed" do
      let(:id) { nil }

      it do
        expect { call }.to change(MessageBlast, :count).by(1)
      end

      it "messages existing_users" do
        expect { call }.to change(Message, :count).by(user_count + 1)
      end

      it "succeeds" do
        expect(call.success?).to be(true)
      end

      it "sets blast context" do
        expect(call.blast).to be_a(ApiEngineBase::Schema::Inbox::BlastResponse)
      end

      context "without existing_users" do
        let(:existing_users) { false }

        it do
          expect { call }.to change(MessageBlast, :count).by(1)
        end

        it "does not message existing_users" do
          expect { call }.to_not change(Message, :count)
        end

        it "succeeds" do
          expect(call.success?).to be(true)
        end

        it "sets blast context" do
          expect(call.blast).to be_a(ApiEngineBase::Schema::Inbox::BlastResponse)
        end
      end
    end
  end
end
