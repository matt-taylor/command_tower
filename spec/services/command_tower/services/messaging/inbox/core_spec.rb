# frozen_string_literal: true

RSpec.describe "Messaging inbox services", :messaging_inbox do
  let(:user) { create(:user) }

  context "when listing inbox items" do
    let!(:item) { create_inbox_for(user:) }

    subject(:result) { CommandTower::Services::Messaging::Inbox::List.call(user:, limit: 50, offset: 0, scope: "inbox") }

    it "lists inbox items" do
      expect(result).to be_success
      expect(result.data[:items].map { |entry| entry[:id] }).to include(item.id)
    end
  end

  context "when opening an inbox item" do
    let!(:item) { create_inbox_for(user:) }

    subject(:result) { CommandTower::Services::Messaging::Inbox::Open.call(user:, inbox_item_id: item.id) }

    it "opens an inbox item" do
      expect(result).to be_success
      expect(result.data[:item][:viewed_at]).to be_present
    end
  end

  context "when bulk marking inbox items read" do
    let!(:item) { create_inbox_for(user:) }

    subject(:result) { CommandTower::Services::Messaging::Inbox::BulkRead.call(user:, inbox_item_ids: [item.id]) }

    it "bulk marks inbox items read" do
      expect(result).to be_success
      expect(result.data[:bulk_result]).to include(ids: [item.id], changed_count: 1)
    end
  end
end
