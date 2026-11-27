# frozen_string_literal: true

RSpec.describe "Me inbox bulk mutations", :with_rbac_setup, :messaging_inbox, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let!(:first) { create_inbox_for(user:) }
  let!(:second) { create_inbox_for(user:) }

  it "marks requested inbox items read" do
    post "/me/inbox/bulk/read", params: { ids: [first.id, second.id] }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"]).to include("ids" => contain_exactly(first.id, second.id), "changedCount" => 2)
    expect([first, second].map(&:reload).map(&:viewed_at)).to all(be_present)
  end

  describe "meta.unreadCount" do
    let(:unread_meta) { response.parsed_body.dig("meta", "unreadCount") }

    it "is 0 after bulk read" do
      post "/me/inbox/bulk/read", params: { ids: [first.id, second.id] }, headers: headers, as: :json

      expect(unread_meta).to eq("count" => 0, "badgeCount" => 0)
    end

    it "reflects the remaining unread rows after bulk unread" do
      post "/me/inbox/bulk/read", params: { ids: [first.id, second.id] }, headers: headers, as: :json
      post "/me/inbox/bulk/unread", params: { ids: [first.id] }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(unread_meta).to eq("count" => 1, "badgeCount" => 1)
      write_inbox_contract_fixture("bulk_unread", response)
    end

    it "drops archived rows from the count on bulk archive" do
      post "/me/inbox/bulk/archive", params: { ids: [first.id] }, headers: headers, as: :json

      expect(unread_meta.fetch("count")).to eq(1)
      write_inbox_contract_fixture("bulk_archive", response)
    end

    it "restores archived rows to the count on bulk restore" do
      post "/me/inbox/bulk/archive", params: { ids: [first.id] }, headers: headers, as: :json
      post "/me/inbox/bulk/restore", params: { ids: [first.id] }, headers: headers, as: :json

      expect(unread_meta.fetch("count")).to eq(2)
      write_inbox_contract_fixture("bulk_restore", response)
    end

    it "drops deleted rows from the count on bulk delete" do
      post "/me/inbox/bulk/delete", params: { ids: [first.id] }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(unread_meta.fetch("count")).to eq(1)
    end
  end
end
