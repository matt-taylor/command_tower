# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Messaging::Inbox::ItemSerializer do
  subject(:payload) do
    described_class.serialize(
      id: 1, title: "Notice", status: "created", viewed_at: nil,
      created_at: Time.zone.parse("2026-01-01 12:00:00"), updated_at: Time.zone.parse("2026-01-01 12:00:00")
    )
  end

  it "uses the modern inbox response keys" do
    expect(payload).to include(id: 1, read: false, viewedAt: nil)
  end
end

RSpec.describe CommandTower::Serializers::Messaging::Inbox::DetailSerializer do
  let(:base_item) do
    { id: 1, title: "Notice", status: "created", viewed_at: nil,
      created_at: Time.zone.parse("2026-01-01 12:00:00"), updated_at: Time.zone.parse("2026-01-01 12:00:00"),
      body: "Body text", metadata: { "deep_link" => "https://example.com" },
      notification_type_key: "example.type", content: { schema: "inbox_document_v1", blocks: [] } }
  end

  subject(:payload) { described_class.serialize(base_item) }

  it "includes body, metadata, notificationTypeKey, and content" do
    expect(payload).to include(
      body: "Body text",
      metadata: { "deep_link" => "https://example.com" },
      notificationTypeKey: "example.type",
      content: { schema: "inbox_document_v1", blocks: [] },
    )
  end

  context "when content is missing from the item Hash" do
    subject(:serialize_call) { described_class.serialize(base_item.except(:content)) }

    it "raises instead of silently omitting content" do
      expect { serialize_call }.to raise_error(KeyError)
    end
  end
end
