# frozen_string_literal: true

RSpec.describe "Inbox conversation fields" do
  let(:source_for) do
    lambda { |path| File.read(CommandTower::Engine.root.join(path)) }
  end

  let(:message) do
    {
      id: 1,
      title: "Notice",
      status: "created",
      viewed_at: nil,
      created_at: Time.zone.parse("2026-01-01 12:00:00"),
      updated_at: Time.zone.parse("2026-01-01 12:00:00"),
      body: "Body",
      metadata: { "deep_link" => "https://example.com/picks" },
      notification_type_key: "example.type",
      content: {
        schema: "inbox_document_v1",
        blocks: [{ type: "paragraph", text: "Body" }],
      },
    }
  end

  subject(:detail) { CommandTower::Serializers::Messaging::Inbox::DetailSerializer.serialize(message) }

  let(:entry) do
    CommandTower::Serializers::Messaging::Inbox::EntrySerializer.serialize(
      kind: "conversation",
      id: "week-5",
      title: "Week 5",
      preview: "Latest",
      activity_at: Time.zone.parse("2026-01-02 12:00:00"),
      created_at: Time.zone.parse("2026-01-02 12:00:00"),
      message_count: 2,
      unread_count: 1,
      read: false,
      inbox_item_ids: [1, 2],
    )
  end

  let(:conversation) do
    CommandTower::Serializers::Messaging::Inbox::ConversationSerializer.serialize(
      scope: "inbox",
      subject: "Week 5",
      message_count: 1,
      unread_count: 1,
      inbox_item_ids: [1],
      messages: [message],
    )
  end

  it "defines no Conversation model" do
    expect(defined?(CommandTower::Messaging::Conversation)).to be_nil
  end

  context "Inbox document rendering source" do
    it "InboxDocument, InboxDocumentRenderer, and TemplateResolver never reference Conversation" do
      %w[
        app/services/command_tower/messaging/rendering/inbox_document.rb
        app/services/command_tower/messaging/rendering/inbox_document_renderer.rb
        app/services/command_tower/messaging/rendering/template_resolver.rb
      ].each do |path|
        expect(source_for.call(path)).not_to match(/conversation/i)
      end
    end
  end

  context "message metadata and document blocks" do
    it "does not carry a conversation key" do
      expect(detail.fetch(:metadata).keys.map(&:to_s)).not_to include(a_string_matching(/conversation/i))
      detail.dig(:content, :blocks).each do |block|
        expect(block.keys.map(&:to_s)).not_to include(a_string_matching(/conversation/i))
      end
    end
  end

  context "grouped list and conversation read" do
    it "allows the entry and conversation fields" do
      expect(entry.keys).to contain_exactly(
        :kind, :id, :title, :preview, :activityAt, :createdAt,
        :messageCount, :unreadCount, :read, :inboxItemIds
      )
      expect(conversation.keys).to contain_exactly(
        :scope, :subject, :messageCount, :unreadCount, :inboxItemIds, :messages
      )
      expect(conversation.dig(:messages, 0).keys.map(&:to_s)).not_to include(a_string_matching(/conversation/i))
    end
  end
end
