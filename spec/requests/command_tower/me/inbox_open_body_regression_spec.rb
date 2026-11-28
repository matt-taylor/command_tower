# frozen_string_literal: true

# Pins the POST /me/inbox/:id/open body for an undefined notification type before the Open refactor.
RSpec.describe "Me inbox open body regression", :messaging_inbox, :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let!(:inbox_item) do
    communication = create(
      :messaging_communication, user:, notification_type_key: "undefined.regression_type", body: "Your picks are due."
    )
    create(:messaging_inbox_item, communication:)
  end

  let(:static_fields) do
    {
      "status" => "viewed",
      "read" => true,
      "body" => "Your picks are due.",
      "metadata" => {},
      "notificationTypeKey" => "undefined.regression_type",
      "content" => {
        "schema" => "inbox_document_v1", "blocks" => [{ "type" => "paragraph", "text" => "Your picks are due." }]
      }
    }
  end
  let(:expected_body) do
    item = inbox_item.reload
    per_item_fields = {
      "id" => item.id,
      "title" => item.communication.title,
      "viewedAt" => item.viewed_at.utc.iso8601,
      "createdAt" => item.created_at.utc.iso8601,
      "updatedAt" => item.updated_at.utc.iso8601
    }
    {
      "data" => per_item_fields.merge(static_fields),
      "meta" => { "unreadCount" => { "count" => 0, "badgeCount" => 0 } },
      "errors" => []
    }
  end

  shared_examples "an unchanged open body" do
    before do
      post "/me/inbox/#{inbox_item.id}/open", headers: authenticate_request_with_bearer!(user).merge(catalog_headers)
    end

    it { expect(response).to have_http_status(:ok) }

    it { expect(inbox_item.reload.viewed_at).to be_present }

    it { expect(response.parsed_body).to eq(expected_body) }
  end

  context "with catalog 1 (no header)" do
    let(:catalog_headers) { {} }

    it_behaves_like "an unchanged open body"
  end

  context "with catalog 2" do
    let(:catalog_headers) { { "X-UI-Catalog" => "2" } }

    it_behaves_like "an unchanged open body"
  end
end
