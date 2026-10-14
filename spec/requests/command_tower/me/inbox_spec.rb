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
    CommandTower::Messaging::NotificationTypes.reset!

    get "/me/inbox/unread-count", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "count")).to eq(1)
    expect(response.parsed_body.dig("data", "badgeCount")).to eq(0)
  end

  context "when unread items differ in badge eligibility", :messaging_notification_types do
    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(key: "badge.on", badge_eligible: true),
        build_notification_type_declaration(
          key: "badge.off",
          badge_eligible: false,
          category_key: "other",
          category_label: "Other",
        ),
      )
    end

    let!(:inbox_item) { nil }
    let!(:eligible_item) do
      communication = create(:messaging_communication, user:, notification_type_key: "badge.on")
      create(:messaging_inbox_item, communication:)
    end
    let!(:ineligible_item) do
      communication = create(:messaging_communication, user:, notification_type_key: "badge.off")
      create(:messaging_inbox_item, communication:)
    end

    it "returns count and badgeCount" do
      get "/me/inbox/unread-count", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "count")).to eq(2)
      expect(response.parsed_body.dig("data", "badgeCount")).to eq(1)
      expect(eligible_item).to be_present
      expect(ineligible_item).to be_present
    end
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

  context "with an item whose communication has a body and a safe deep_link" do
    let(:communication) do
      create(:messaging_communication, user:, body: "Your picks are due.", metadata: { "deep_link" => "https://example.com/picks", "cta_label" => "Make picks" })
    end
    let!(:content_inbox_item) { create(:messaging_inbox_item, communication:) }

    it "includes an inbox_document_v1 content document on show" do
      get "/me/inbox/#{content_inbox_item.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "content")).to eq(
        "schema" => "inbox_document_v1",
        "blocks" => [
          { "type" => "paragraph", "text" => "Your picks are due." },
          {
            "type" => "cta",
            "label" => "Make picks",
            "destination" => { "kind" => "external", "href" => "https://example.com/picks" },
          },
        ],
      )
    end

    it "includes an inbox_document_v1 content document on open" do
      post "/me/inbox/#{content_inbox_item.id}/open", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "content", "schema")).to eq("inbox_document_v1")
    end

    it "omits content from the list response" do
      get "/me/inbox", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].find { |item| item["id"] == content_inbox_item.id }).not_to have_key("content")
    end
  end

  context "when the communication stores a presentation snapshot", :messaging_notification_types do
    before do
      register_and_seal_notification_types(
        build_notification_type_declaration(
          key: "example.type",
          inbox_document_composer:
            "CommandTower::Messaging::Rendering::InboxDocumentRendererSpecDoubles::TypeComposerWithPresentation",
        ),
      )
    end

    let(:communication) do
      create(
        :messaging_communication,
        user:,
        notification_type_key: "example.type",
        body: "Narrative",
        inbox_presentation_snapshot: {
          "v" => 1,
          "key" => "rich_messaging_proof.make_picks",
          "variant" => "compact",
          "data" => { "example" => "stored" },
        },
      )
    end
    let!(:snapshot_inbox_item) { create(:messaging_inbox_item, communication:) }

    subject(:show_response) do
      get "/me/inbox/#{snapshot_inbox_item.id}", headers: headers
      response
    end

    it "returns the stored presentation data" do
      expect(show_response).to have_http_status(:ok)
      expect(show_response.parsed_body.dig("data", "content", "blocks")).to include(
        "type" => "presentation",
        "key" => "rich_messaging_proof.make_picks",
        "variant" => "compact",
        "data" => { "example" => "stored" },
      )
    end
  end

  context "when a newer message has a lower id than an older message in the same key" do
    let!(:inbox_item) { nil }
    let(:newer_communication) do
      create(:messaging_communication, user:, title: "Newer notice", conversation_key: "week-5", conversation_title: "Week 5")
    end
    let(:older_communication) do
      create(:messaging_communication, user:, title: "Older notice", conversation_key: "week-5", conversation_title: "Old Week")
    end
    let(:standalone_communication) { create(:messaging_communication, user:, title: "Alone") }
    let!(:newer_item) { create(:messaging_inbox_item, communication: newer_communication) }
    let!(:older_item) { create(:messaging_inbox_item, communication: older_communication) }
    let!(:standalone) { create(:messaging_inbox_item, communication: standalone_communication) }

    before do
      newer_item.update_columns(created_at: 1.hour.ago, updated_at: 1.hour.ago)
      older_item.update_columns(created_at: 4.days.ago, updated_at: 4.days.ago)
      standalone.update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)
    end

    subject(:list_body) do
      get "/me/inbox", headers: headers
      response.parsed_body
    end

    let(:detail_body) do
      get "/me/inbox/conversation", params: { key: "week-5", scope: "inbox" }, headers: headers
      response.parsed_body
    end

    it "orders by the newer message and uses that message for the title and preview" do
      expect(older_item.id).to be > newer_item.id
      expect(list_body.fetch("data").map { |entry| entry["id"] }).to eq(["week-5", standalone.id])
      expect(list_body.dig("data", 0)).to include(
        "kind" => "conversation",
        "title" => "Week 5",
        "preview" => "Newer notice",
        "messageCount" => 2,
        "inboxItemIds" => [older_item.id, newer_item.id],
      )
      expect(list_body.dig("data", 0, "createdAt")).to eq(list_body.dig("data", 0, "activityAt"))
      expect(list_body.dig("data", 0, "activityAt")).to eq(newer_item.reload.created_at.iso8601)
      expect(list_body.dig("data", 1)).to include("kind" => "message", "title" => "Alone", "preview" => nil, "messageCount" => 1)
    end

    it "returns the newer subject and leaves the messages unread" do
      expect(detail_body.dig("data", "subject")).to eq("Week 5")
      expect(detail_body.dig("data", "messages").map { |message| message["title"] }).to eq(["Older notice", "Newer notice"])
      expect(newer_item.reload.viewed_at).to be_nil
      expect(older_item.reload.viewed_at).to be_nil
    end
  end

  context "when a conversation has one archived member" do
    let!(:inbox_item) { nil }
    let(:active_communication) do
      create(:messaging_communication, user:, title: "Active notice", conversation_key: "week-5", conversation_title: "Week 5")
    end
    let(:archived_communication) do
      create(:messaging_communication, user:, title: "Archived notice", conversation_key: "week-5", conversation_title: "Week 5")
    end
    let!(:active_item) { create(:messaging_inbox_item, communication: active_communication) }
    let!(:archived_item) { create(:messaging_inbox_item, :archived, communication: archived_communication) }

    let(:inbox_body) do
      get "/me/inbox", headers: headers
      response.parsed_body
    end
    let(:archived_list_body) do
      get "/me/inbox", params: { scope: "archived" }, headers: headers
      response.parsed_body
    end
    let(:inbox_detail) do
      get "/me/inbox/conversation", params: { key: "week-5", scope: "inbox" }, headers: headers
      response.parsed_body
    end
    let(:archived_detail) do
      get "/me/inbox/conversation", params: { key: "week-5", scope: "archived" }, headers: headers
      response.parsed_body
    end

    it "keeps each scope to its own member" do
      expect(inbox_body.dig("data", 0)).to include(
        "messageCount" => 1,
        "unreadCount" => 1,
        "preview" => "Active notice",
        "inboxItemIds" => [active_item.id],
      )
      expect(archived_list_body.dig("data", 0)).to include(
        "messageCount" => 1,
        "preview" => "Archived notice",
        "inboxItemIds" => [archived_item.id],
      )
      expect(inbox_detail.dig("data", "inboxItemIds")).to eq([active_item.id])
      expect(inbox_detail.dig("data", "messages").map { |message| message["id"] }).to eq([active_item.id])
      expect(archived_detail.dig("data", "inboxItemIds")).to eq([archived_item.id])
      expect(archived_detail.dig("data", "messages").map { |message| message["id"] }).to eq([archived_item.id])
    end
  end

  context "when the list page splits entries" do
    let!(:inbox_item) { nil }
    let(:newer_communication) do
      create(:messaging_communication, user:, title: "Newer notice", conversation_key: "week-5", conversation_title: "Week 5")
    end
    let(:older_communication) do
      create(:messaging_communication, user:, title: "Older notice", conversation_key: "week-5", conversation_title: "Week 5")
    end
    let!(:newer_item) { create(:messaging_inbox_item, communication: newer_communication) }
    let!(:older_item) { create(:messaging_inbox_item, communication: older_communication) }
    let!(:middle_item) { create_inbox_for(user:) }
    let!(:oldest_item) { create_inbox_for(user:) }

    before do
      newer_item.update_columns(created_at: 1.hour.ago, updated_at: 1.hour.ago)
      middle_item.update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)
      oldest_item.update_columns(created_at: 3.days.ago, updated_at: 3.days.ago)
      older_item.update_columns(created_at: 4.days.ago, updated_at: 4.days.ago)
    end

    let(:first_page) do
      get "/me/inbox", params: { limit: 1, offset: 0 }, headers: headers
      response.parsed_body
    end
    let(:second_page) do
      get "/me/inbox", params: { limit: 1, offset: 1 }, headers: headers
      response.parsed_body
    end

    it "pages entries and keeps every member id on the conversation entry" do
      expect(first_page.dig("meta", "totalCount")).to eq(3)
      expect(first_page.fetch("data").size).to eq(1)
      expect(first_page.dig("data", 0, "id")).to eq("week-5")
      expect(first_page.dig("data", 0, "inboxItemIds")).to eq([older_item.id, newer_item.id])
      expect(second_page.fetch("data").size).to eq(1)
      expect(second_page.dig("data", 0, "messageCount")).to eq(1)
      expect(second_page.dig("data", 0, "inboxItemIds")).to eq([middle_item.id])
    end
  end

  context "when the full in-scope id set is archived" do
    let!(:inbox_item) { nil }
    let(:first_communication) do
      create(:messaging_communication, user:, title: "One", conversation_key: "week-5", conversation_title: "Week 5")
    end
    let(:second_communication) do
      create(:messaging_communication, user:, title: "Two", conversation_key: "week-5", conversation_title: "Week 5")
    end
    let!(:first_member) { create(:messaging_inbox_item, communication: first_communication) }
    let!(:second_member) { create(:messaging_inbox_item, communication: second_communication) }
    let!(:outsider) { create_inbox_for(user:) }
    let(:member_ids) do
      get "/me/inbox", headers: headers
      response.parsed_body.fetch("data").find { |entry| entry["id"] == "week-5" }.fetch("inboxItemIds")
    end

    before do
      post "/me/inbox/bulk/archive", params: { ids: member_ids }, headers: headers, as: :json
    end

    let(:inbox_body) do
      get "/me/inbox", headers: headers
      response.parsed_body
    end
    let(:archived_body) do
      get "/me/inbox", params: { scope: "archived" }, headers: headers
      response.parsed_body
    end

    it "moves that set to the archived scope and leaves other messages" do
      expect(member_ids).to contain_exactly(first_member.id, second_member.id)
      expect(inbox_body.fetch("data").map { |entry| entry["id"] }).to eq([outsider.id])
      expect(archived_body.fetch("data").map { |entry| entry["id"] }).to eq(["week-5"])
      expect(archived_body.dig("data", 0, "inboxItemIds")).to contain_exactly(first_member.id, second_member.id)
      expect(first_member.reload.archived_at).to be_present
      expect(second_member.reload.archived_at).to be_present
      expect(first_member.deleted_at).to be_nil
      expect(outsider.reload.archived_at).to be_nil
    end
  end

  context "when the full in-scope id set is deleted" do
    let!(:inbox_item) { nil }
    let(:first_communication) do
      create(:messaging_communication, user:, title: "One", conversation_key: "week-5", conversation_title: "Week 5")
    end
    let(:second_communication) do
      create(:messaging_communication, user:, title: "Two", conversation_key: "week-5", conversation_title: "Week 5")
    end
    let!(:first_member) { create(:messaging_inbox_item, communication: first_communication) }
    let!(:second_member) { create(:messaging_inbox_item, communication: second_communication) }
    let!(:outsider) { create_inbox_for(user:) }
    let(:member_ids) do
      get "/me/inbox", headers: headers
      response.parsed_body.fetch("data").find { |entry| entry["id"] == "week-5" }.fetch("inboxItemIds")
    end

    before do
      post "/me/inbox/bulk/delete", params: { ids: member_ids }, headers: headers, as: :json
    end

    let(:inbox_body) do
      get "/me/inbox", headers: headers
      response.parsed_body
    end
    let(:archived_body) do
      get "/me/inbox", params: { scope: "archived" }, headers: headers
      response.parsed_body
    end

    it "removes that set without archiving it" do
      expect(member_ids).to contain_exactly(first_member.id, second_member.id)
      expect(inbox_body.fetch("data").map { |entry| entry["id"] }).to eq([outsider.id])
      expect(archived_body.fetch("data")).to eq([])
      expect(first_member.reload.deleted_at).to be_present
      expect(first_member.archived_at).to be_nil
      expect(second_member.reload.deleted_at).to be_present
      expect(second_member.archived_at).to be_nil
      expect(outsider.reload.deleted_at).to be_nil
    end
  end

  context "when the key belongs to someone else" do
    let!(:inbox_item) { nil }
    let(:other_user) { create(:user, roles: ["member"]) }
    let(:other_communication) do
      create(:messaging_communication, user: other_user, conversation_key: "week-5", conversation_title: "Week 5")
    end
    let!(:other_item) { create(:messaging_inbox_item, communication: other_communication) }

    subject(:conversation_response) do
      get "/me/inbox/conversation", params: { key: "week-5" }, headers: headers
      response
    end

    it "is not found" do
      expect(conversation_response).to have_http_status(:not_found)
    end
  end

  context "when the key is unknown" do
    subject(:conversation_response) do
      get "/me/inbox/conversation", params: { key: "missing-key" }, headers: headers
      response
    end

    it "is not found" do
      expect(conversation_response).to have_http_status(:not_found)
    end

    it "is not found when a window is requested" do
      get "/me/inbox/conversation", params: { key: "missing-key", around: "oldest_unread" }, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  context "when the conversation key is blank" do
    subject(:conversation_response) do
      get "/me/inbox/conversation", params: { key: "  " }, headers: headers
      response
    end

    it "rejects the key" do
      expect(conversation_response).to have_http_status(:unprocessable_entity)
    end
  end

  context "when a conversation has two unread members" do
    let!(:inbox_item) { nil }
    let(:first_communication) do
      create(:messaging_communication, user:, conversation_key: "week-5", conversation_title: "Week 5")
    end
    let(:second_communication) do
      create(:messaging_communication, user:, conversation_key: "week-5", conversation_title: "Week 5")
    end
    let!(:first_member) { create(:messaging_inbox_item, communication: first_communication) }
    let!(:second_member) { create(:messaging_inbox_item, communication: second_communication) }

    subject(:count_response) do
      get "/me/inbox/unread-count", headers: headers
      response
    end

    it "counts inbox items" do
      expect(count_response).to have_http_status(:ok)
      expect(count_response.parsed_body.dig("data", "count")).to eq(2)
      expect(count_response.parsed_body.dig("data", "badgeCount")).to eq(0)
    end
  end

  context "when a conversation is longer than the window" do
    let!(:inbox_item) { nil }
    let!(:members) do
      Array.new(8) do |index|
        communication = create(
          :messaging_communication,
          user:,
          title: "Notice #{index}",
          conversation_key: "week-5",
          conversation_title: "Week 5",
        )
        create(:messaging_inbox_item, communication:)
      end
    end
    let(:conversation_params) { { key: "week-5", scope: "inbox" } }

    before do
      base = Time.zone.parse("2026-10-01 12:00:00")
      members.each_with_index do |item, index|
        item.update_columns(created_at: base + index.minutes, updated_at: base + index.minutes)
      end
      allow(CommandTower::Messaging::Rendering::InboxDocumentRenderer).to receive(:render).and_call_original
      members.first(3).each do |item|
        item.update_columns(
          viewed_at: Time.current,
          status: CommandTower::Messaging::InboxItem::STATUS_VIEWED,
          updated_at: item.updated_at,
        )
      end
    end

    subject(:conversation_response) do
      get "/me/inbox/conversation", params: conversation_params, headers: headers
      response
    end

    let(:conversation_body) { conversation_response.parsed_body }

    it "returns every member when no window is requested" do
      expect(conversation_response).to have_http_status(:ok)
      expect(conversation_body.fetch("data")).not_to have_key("window")
      expect(conversation_body.dig("data", "messages").map { |message| message["id"] }).to eq(members.map(&:id))
      expect(conversation_body.dig("data", "inboxItemIds")).to eq(members.map(&:id))
      expect(CommandTower::Messaging::Rendering::InboxDocumentRenderer).to have_received(:render).exactly(members.size).times
    end

    context "when the window is around the oldest unread" do
      let(:conversation_params) { super().merge(around: "oldest_unread") }

      it "leaves the rest unrendered" do
        expect(conversation_response).to have_http_status(:ok)
        expect(conversation_body.dig("data", "messageCount")).to eq(8)
        expect(conversation_body.dig("data", "unreadCount")).to eq(5)
        expect(conversation_body.dig("data", "inboxItemIds")).to eq(members.map(&:id))
        expect(conversation_body.dig("data", "messages").map { |message| message["id"] }).to eq(members[1..5].map(&:id))
        expect(conversation_body.dig("data", "window")).to include(
          "anchorInboxItemId" => members[3].id,
          "hasBefore" => true,
          "hasAfter" => true,
          "beforeCursor" => members[1].id,
          "afterCursor" => members[5].id,
        )
        expect(CommandTower::Messaging::Rendering::InboxDocumentRenderer).to have_received(:render).exactly(5).times
      end
    end

    context "when every member is read" do
      let(:conversation_params) { super().merge(around: "oldest_unread") }

      before do
        members.each do |item|
          item.update_columns(
            viewed_at: Time.current,
            status: CommandTower::Messaging::InboxItem::STATUS_VIEWED,
            updated_at: item.updated_at,
          )
        end
      end

      it "lands on the latest message" do
        expect(conversation_body.dig("data", "messages").map { |message| message["id"] }).to eq(members.last(3).map(&:id))
        expect(conversation_body.dig("data", "window")).to include(
          "anchorInboxItemId" => members.last.id,
          "hasAfter" => false,
        )
        expect(conversation_body.dig("data", "unreadCount")).to eq(0)
      end
    end

    context "when the before cursor is the first member" do
      let(:conversation_params) { super().merge(before: members.first.id) }

      it "returns an empty page without changing the summary" do
        expect(conversation_body.dig("data", "messages")).to eq([])
        expect(conversation_body.dig("data", "messageCount")).to eq(8)
        expect(conversation_body.dig("data", "inboxItemIds")).to eq(members.map(&:id))
        expect(conversation_body.dig("data", "window", "hasBefore")).to be(false)
      end
    end

    context "when the after cursor is the last member" do
      let(:conversation_params) { super().merge(after: members.last.id) }

      it "returns an empty page without changing the summary" do
        expect(conversation_body.dig("data", "messages")).to eq([])
        expect(conversation_body.dig("data", "messageCount")).to eq(8)
        expect(conversation_body.dig("data", "window", "hasAfter")).to be(false)
      end
    end

    context "when a newer member arrives after the anchored window" do
      let(:anchored_window) do
        get "/me/inbox/conversation", params: { key: "week-5", scope: "inbox", around: "oldest_unread" }, headers: headers
        response.parsed_body.dig("data", "window")
      end
      let(:newest_communication) do
        create(
          :messaging_communication,
          user:,
          title: "Newest notice",
          conversation_key: "week-5",
          conversation_title: "Week 5",
        )
      end
      let!(:newest) do
        anchored_window
        item = create(:messaging_inbox_item, communication: newest_communication)
        item.update_columns(created_at: members.last.created_at + 1.minute, updated_at: members.last.updated_at)
        item
      end
      let(:after_page) do
        get "/me/inbox/conversation",
            params: { key: "week-5", scope: "inbox", after: anchored_window.fetch("afterCursor") },
            headers: headers
        response.parsed_body
      end
      let(:anchored_page) do
        get "/me/inbox/conversation",
            params: { key: "week-5", scope: "inbox", around: members[3].id },
            headers: headers
        response.parsed_body
      end

      it "returns that member on the next page and not inside the anchored window" do
        expect(after_page.dig("data", "messages").map { |message| message["id"] }).to include(newest.id)
        expect(anchored_page.dig("data", "messages").map { |message| message["id"] }).not_to include(newest.id)
        expect(anchored_page.dig("data", "messages").map { |message| message["id"] }).to eq(members[1..5].map(&:id))
      end
    end

    context "when the limit is above 5" do
      let(:conversation_params) { super().merge(around: "oldest_unread", limit: 6) }

      it "rejects the limit" do
        expect(conversation_response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when the limit is 15" do
      let(:conversation_params) { super().merge(around: "oldest_unread", limit: 15) }

      it "rejects the limit" do
        expect(conversation_response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when before and after are both present" do
      let(:conversation_params) { super().merge(before: members[4].id, after: members[5].id) }

      it "rejects the cursors" do
        expect(conversation_response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when the cursor belongs to another key" do
      let(:other_communication) do
        create(:messaging_communication, user:, conversation_key: "other-week", conversation_title: "Other")
      end
      let!(:other_item) { create(:messaging_inbox_item, communication: other_communication) }
      let(:conversation_params) { super().merge(before: other_item.id) }

      it "rejects the cursor" do
        expect(conversation_response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  context "when a window cursor is outside the requested scope" do
    let!(:inbox_item) { nil }
    let(:active_communication) do
      create(:messaging_communication, user:, title: "Active notice", conversation_key: "week-5", conversation_title: "Week 5")
    end
    let(:archived_communication) do
      create(:messaging_communication, user:, title: "Archived notice", conversation_key: "week-5", conversation_title: "Week 5")
    end
    let!(:active_item) { create(:messaging_inbox_item, communication: active_communication) }
    let!(:archived_item) { create(:messaging_inbox_item, :archived, communication: archived_communication) }

    it "does not accept an inbox id as an archived cursor" do
      get "/me/inbox/conversation", params: { key: "week-5", scope: "archived", before: active_item.id }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(archived_item.id).not_to eq(active_item.id)
    end
  end

  context "when a window cursor belongs to someone else" do
    let!(:inbox_item) { nil }
    let(:communication) do
      create(:messaging_communication, user:, conversation_key: "week-5", conversation_title: "Week 5")
    end
    let!(:member) { create(:messaging_inbox_item, communication:) }
    let(:other_user) { create(:user, roles: ["member"]) }
    let(:other_communication) do
      create(:messaging_communication, user: other_user, conversation_key: "week-5", conversation_title: "Week 5")
    end
    let!(:other_item) { create(:messaging_inbox_item, communication: other_communication) }

    it "rejects the cursor" do
      get "/me/inbox/conversation", params: { key: "week-5", before: other_item.id }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(member.id).not_to eq(other_item.id)
    end
  end
end
