# frozen_string_literal: true

RSpec.describe "Messaging inbox workflows", :messaging_inbox do
  let(:user) { create(:user) }

  context "when listing inbox items" do
    let!(:item) { create_inbox_for(user:) }

    subject(:result) do
      CommandTower::Workflows::Messaging::Inbox::ListWorkflow.call(user:, limit: 50, offset: 0, scope: "inbox")
    end

    it "serializes a listed inbox item" do
      expect(result).to be_success
      expect(result.payload.map { |entry| entry[:id] }).to include(item.id)
    end
  end

  context "when opening an inbox item" do
    let!(:item) { create_inbox_for(user:) }
    let(:viewed_events) { CommandTower::Audit::Event.where(action: "messaging_inbox_item_viewed") }

    subject(:result) { CommandTower::Workflows::Messaging::Inbox::OpenWorkflow.call(user:, inbox_item_id: item.id) }

    it "opens an item through its workflow" do
      expect(result).to be_success
      expect(result.payload[:read]).to be(true)
    end

    it "emits one event across repeat opens" do
      expect do
        result
        CommandTower::Workflows::Messaging::Inbox::OpenWorkflow.call(user:, inbox_item_id: item.id)
      end.to change(viewed_events, :count).by(1)
    end

    it "records ids only in the event metadata" do
      result
      expect(viewed_events.last.metadata).to eq("inbox_item_id" => item.id, "communication_id" => item.communication_id)
    end

    it "does not audit bulk read" do
      expect do
        CommandTower::Workflows::Messaging::Inbox::BulkReadWorkflow.call(user:, inbox_item_ids: [item.id])
      end.not_to change(viewed_events, :count)
    end

    it "does not audit Show" do
      expect do
        CommandTower::Workflows::Messaging::Inbox::ShowWorkflow.call(user:, inbox_item_id: item.id)
      end.not_to change(viewed_events, :count)
    end

    context "when impersonated" do
      around do |example|
        CommandTower::Current.set(impersonation_active: true) { example.run }
      end

      it "returns the detail without auditing" do
        expect { result }.not_to change(viewed_events, :count)
        expect(result).to be_success
      end

      it "does not mark the item viewed" do
        result
        expect(item.reload.viewed_at).to be_nil
      end
    end
  end

  context "when bulk marking inbox items read" do
    let!(:item) { create_inbox_for(user:) }

    subject(:result) do
      CommandTower::Workflows::Messaging::Inbox::BulkReadWorkflow.call(user:, inbox_item_ids: [item.id])
    end

    it "serializes a bulk read result" do
      expect(result).to be_success
      expect(result.payload).to include(ids: [item.id], changedCount: 1)
    end
  end
end
