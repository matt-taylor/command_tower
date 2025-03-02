# frozen_string_literal: true

RSpec.describe CommandTower::InboxService::Message::Modify do
  let(:user) { create(:user) }
  let!(:messages) { create_list(:message, count,user:) }
  let(:count) { 5 }
  let(:ids) { messages.map(&:id) }

  describe ".call" do
    subject(:call) { described_class.(user:, ids:, type:) }

    shared_examples "modified" do
      it "succeeds" do
        expect(call.success?).to eq(true)
      end

      it "returns modified" do
        expect(call.modified).to be_a(CommandTower::Schema::Inbox::Modified)
        expect(call.modified.type).to eq(type)
        expect(call.modified.ids).to include(*ids)
        expect(call.modified.count).to eq(count)
      end

      context "with no ID's available" do
        let(:ids) { [12345678] }

        it "fails" do
          expect(call.failure?).to eq(true)
        end
      end

      context "with additional ids that are not available" do
        let(:ids) { super() << additional_id }
        let(:additional_id) { 100 }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "returns modified" do
          expect(call.modified).to be_a(CommandTower::Schema::Inbox::Modified)
          expect(call.modified.type).to eq(type)
          expect(call.modified.ids).to include(*ids.reject { _1 == additional_id })
          expect(call.modified.count).to eq(count)
        end
      end
    end

    context "with viewed" do
      let(:type) { :viewed }

      include_examples "modified"

      it "changes all viewed to true" do
        call

        expect(messages.map(&:reload).pluck(:viewed)).to all(eq(true))
      end

      context "when some are already read" do
        before { messages.sample.update(viewed: true) }

        include_examples "modified"
      end
    end

    context "with delete" do
      let(:type) { :delete }

      include_examples "modified"

      it "deletes records" do
        expect { call }.to change(Message, :count).by(-count)
      end
    end
  end
end
