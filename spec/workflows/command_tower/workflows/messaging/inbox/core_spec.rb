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

    subject(:result) { CommandTower::Workflows::Messaging::Inbox::OpenWorkflow.call(user:, inbox_item_id: item.id) }

    it "opens an item through its workflow" do
      expect(result).to be_success
      expect(result.payload[:read]).to be(true)
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
