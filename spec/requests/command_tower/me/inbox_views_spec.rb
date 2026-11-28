# frozen_string_literal: true

RSpec.describe "Me inbox views", :messaging_inbox, :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let!(:first) { create_inbox_for(user:) }
  let!(:second) { create_inbox_for(user:) }

  describe "recording views" do
    before { post_inbox_views([first.id], authenticate_request_with_bearer!(user)) }

    it { expect(inbox_data).to eq("viewedIds" => [first.id], "changedCount" => 1, "unavailableIds" => []) }
    it { expect(inbox_unread_meta).to eq("count" => 1, "badgeCount" => 1) }
    it { expect(first.reload.viewed_at).to be_present }

    it "writes the contract fixture" do
      write_inbox_contract_fixture("views", response)
      expect(response).to have_http_status(:ok)
    end

    it "emits one event per first view only" do
      expect { post_inbox_views([first.id, second.id], authenticate_request_with_bearer!(user)) }
        .to change(inbox_viewed_events, :count).by(1)
    end
  end

  describe "unavailable ids" do
    # [foreign recipient's item, soft-deleted item]
    let(:unavailable) do
      deleted = create_inbox_for(user:)
      deleted.update!(deleted_at: Time.current, status: CommandTower::Messaging::InboxItem::STATUS_DELETED)
      [create_inbox_for(user: create(:user)), deleted]
    end

    let(:unavailable_ids) { unavailable.map(&:id) + [unavailable.last.id + 9999] }

    before { post_inbox_views([first.id, *unavailable_ids], authenticate_request_with_bearer!(user)) }

    it { expect(response).to have_http_status(:ok) }
    it { expect(inbox_data["viewedIds"]).to eq([first.id]) }
    it { expect(inbox_data["unavailableIds"]).to match_array(unavailable_ids) }
    it { expect(unavailable.first.reload.viewed_at).to be_nil }
  end

  describe "validation" do
    it "rejects more than 100 ids" do
      post_inbox_views((1..101).to_a, authenticate_request_with_bearer!(user))
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects an empty ids list" do
      post_inbox_views([], authenticate_request_with_bearer!(user))
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "when impersonating" do
    # A body that would fail validation proves the skip runs first.
    before do
      operator = create(:user, :role_impersonation_operator)
      session = create(
        :impersonation_session,
        actor: operator, target: user, idle_expires_at: 2.minutes.from_now, absolute_expires_at: 1.hour.from_now
      )
      post_inbox_views("not-a-list", authenticate_impersonation_with_bearer!(operator, session))
    end

    it { expect(inbox_data).to include("skipped" => "impersonating", "viewedIds" => [], "unavailableIds" => []) }
    it { expect(inbox_unread_meta).to eq("count" => 2, "badgeCount" => 2) }
    it { expect(first.reload.viewed_at).to be_nil }
    it { expect(inbox_viewed_events.count).to eq(0) }
  end
end
