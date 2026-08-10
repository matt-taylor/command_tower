# frozen_string_literal: true

RSpec.describe "Me inbox", :with_rbac_setup, :messaging_inbox, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let!(:inbox_item) { create_inbox_for(user:) }

  it "rejects unauthenticated requests" do
    get "/me/inbox"

    expect(response).to have_http_status(:unauthorized)
  end

  it "lists inbox items for a member" do
    get "/me/inbox", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"].map { |item| item["id"] }).to include(inbox_item.id)
  end

  context "when the caller lacks roles" do
    let(:unprivileged_user) { create(:user, roles: []) }
    let(:unprivileged_headers) { authenticate_request_with_bearer!(unprivileged_user) }

    before { get "/me/inbox", headers: unprivileged_headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  it "returns unread count" do
    get "/me/inbox/unread-count", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "count")).to eq(1)
  end

  it "shows, opens, archives, and deletes an owned item" do
    get "/me/inbox/#{inbox_item.id}", headers: headers
    expect(response).to have_http_status(:ok)

    post "/me/inbox/#{inbox_item.id}/open", headers: headers
    expect(response).to have_http_status(:ok)
    expect(inbox_item.reload.viewed_at).to be_present

    patch "/me/inbox/#{inbox_item.id}/archive", headers: headers
    expect(response).to have_http_status(:ok)

    delete "/me/inbox/#{inbox_item.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(inbox_item.reload.deleted_at).to be_present
  end
end
