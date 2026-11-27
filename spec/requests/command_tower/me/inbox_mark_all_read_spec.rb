# frozen_string_literal: true

RSpec.describe "Me inbox mark all read", :messaging_inbox, :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let!(:first) { create_inbox_for(user:) }
  let!(:second) { create_inbox_for(user:) }
  let!(:later) { create_inbox_for(user:) }

  describe "watermark" do
    before { post_inbox_mark_all_read(second.id, user) }

    it { expect(response).to have_http_status(:ok) }
    it { expect(inbox_data).to include("ids" => [first.id, second.id], "changedCount" => 2) }
    it { expect(inbox_unread_meta).to eq("count" => 1, "badgeCount" => 1) }
    it { expect([first, second].map { |item| item.reload.viewed_at }).to all(be_present) }
    it { expect(later.reload.viewed_at).to be_nil }

    it "writes the contract fixture" do
      write_inbox_contract_fixture("mark_all_read", response)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "rows that do not count as unread" do
    # [archived item, another recipient's item]
    let(:skipped) { [create_inbox_for(user:), create_inbox_for(user: create(:user))] }

    before do
      skipped.first.update!(archived_at: Time.current, status: CommandTower::Messaging::InboxItem::STATUS_ARCHIVED)
      post_inbox_mark_all_read(skipped.last.id, user)
    end

    it { expect(skipped.first.reload.viewed_at).to be_nil }
    it { expect(skipped.last.reload.viewed_at).to be_nil }
    it { expect(inbox_data["ids"]).to contain_exactly(first.id, second.id, later.id) }
  end

  describe "when everything is archived (Archived-segment no-op)" do
    before do
      [first, second, later].each do |item|
        item.update!(archived_at: Time.current, status: CommandTower::Messaging::InboxItem::STATUS_ARCHIVED)
      end
      post_inbox_mark_all_read(later.id, user)
    end

    it { expect(inbox_data).to include("ids" => [], "changedCount" => 0) }
    it { expect([first, second, later].map { |item| item.reload.viewed_at }).to all(be_nil) }
  end

  describe "repeating the call" do
    before { post_inbox_mark_all_read(later.id, user) }

    it "changes nothing the second time" do
      post_inbox_mark_all_read(later.id, user)
      expect(inbox_data).to include("changedCount" => 0)
    end
  end

  describe "validation" do
    it "rejects a missing upTo" do
      post "/me/inbox/mark-all-read", params: {}, headers: authenticate_request_with_bearer!(user), as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a non-numeric upTo" do
      post_inbox_mark_all_read("abc", user)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects zero" do
      post_inbox_mark_all_read(0, user)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
